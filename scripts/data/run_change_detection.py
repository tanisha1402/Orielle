#!/usr/bin/env python
"""Run the local TERRALENS before/after Sentinel-1 VV change analysis."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from pathlib import PurePosixPath
from typing import Any

import numpy as np
import rasterio
from affine import Affine
from rasterio.crs import CRS
from rasterio.errors import RasterioError
from rasterio.io import DatasetReader
from rasterio.transform import array_bounds

from src.compute.change import (
    DEFAULT_MIN_COMPONENT_PIXELS,
    DEFAULT_WATER_THRESHOLD_DB,
    ChangeDetectionResult,
    detect_water_change_geospatial,
)

ROOT = Path(__file__).resolve().parents[2]
SAR_DIR = ROOT / "cache" / "sar"
OUTPUT_DIR = ROOT / "cache" / "outputs"
SOURCE_SCENE_PATTERN = re.compile(
    r"The source granule used to generate the products contained in this folder is:"
    r"\s*(S1[A-Z0-9_]+)",
    re.IGNORECASE,
)


def _read_metadata(metadata_path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(metadata_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(
            f"Invalid scene metadata JSON at {metadata_path}: {error}"
        ) from error

    if not isinstance(payload, dict) or not isinstance(payload.get("scenes"), list):
        raise ValueError(
            f"{metadata_path} must contain a top-level 'scenes' array."
        )
    return payload


def _read_cached_product_manifest(archive_path: Path) -> tuple[str, str, str]:
    try:
        with zipfile.ZipFile(archive_path) as archive:
            readme_names = [
                name
                for name in archive.namelist()
                if PurePosixPath(name).name.endswith("README.md.txt")
            ]
            log_names = [
                name
                for name in archive.namelist()
                if PurePosixPath(name).suffix.lower() == ".log"
            ]
            if len(readme_names) != 1 or len(log_names) != 1:
                raise ValueError(
                    f"{archive_path}: expected one HyP3 README and processing log."
                )
            readme = archive.read(readme_names[0]).decode(
                "utf-8", errors="replace"
            )
            log = archive.read(log_names[0]).decode("utf-8", errors="replace")
    except (OSError, zipfile.BadZipFile, KeyError) as error:
        raise ValueError(
            f"Unable to read HyP3 metadata from {archive_path}: {error}"
        ) from error

    scene_match = SOURCE_SCENE_PATTERN.search(readme)
    if scene_match is None:
        raise ValueError(
            f"{archive_path}: README does not identify its source granule."
        )
    if not re.search(r"output\s+sigma-0\s+power", readme, re.IGNORECASE):
        raise ValueError(
            f"{archive_path}: README does not confirm Sigma0 power output."
        )
    if not re.search(r"pixel spacing of 10 meters", readme, re.IGNORECASE):
        raise ValueError(
            f"{archive_path}: README does not confirm 10 m pixel spacing."
        )
    if not re.search(r"Radiometry\s*:\s*sigma0\b", log, re.IGNORECASE):
        raise ValueError(
            f"{archive_path}: processing log does not confirm Sigma0 radiometry."
        )
    if not re.search(r"DEM name\s*:\s*copernicus\b", log, re.IGNORECASE):
        raise ValueError(
            f"{archive_path}: processing log does not confirm the Copernicus DEM."
        )

    return scene_match.group(1), readme, log


def _cached_raster_metadata(path: Path, *, project_root: Path) -> dict[str, Any]:
    with rasterio.open(path) as dataset:
        return {
            "path": path.resolve().relative_to(project_root.resolve()).as_posix(),
            **_dataset_grid_metadata(path, dataset),
        }


def _dataset_grid_metadata(
    path: Path,
    dataset: DatasetReader,
) -> dict[str, Any]:
    if dataset.crs is None:
        raise ValueError(f"{path}: raster has no CRS.")
    if dataset.count != 1:
        raise ValueError(f"{path}: expected a single-band polarization raster.")
    return {
        "crs": dataset.crs.to_string(),
        "resolution_m": _pixel_spacing_m(dataset),
        "width": dataset.width,
        "height": dataset.height,
        "bounds": [float(value) for value in dataset.bounds],
        "nodata": dataset.nodata,
        "transform": [float(value) for value in dataset.transform],
        "dtype": dataset.dtypes[0],
    }


def _rebuild_metadata_from_cached_products(
    sar_dir: Path,
    *,
    project_root: Path,
) -> dict[str, Any]:
    """Reconstruct scene records from local COGs and their downloaded manifests."""

    scenes = []
    for role in ("before", "after"):
        scene_dirs = sorted(
            path
            for path in sar_dir.glob(f"{role}-*")
            if path.is_dir()
        )
        if len(scene_dirs) != 1:
            raise ValueError(
                f"Cannot recover metadata: expected one {role} scene directory "
                f"under {sar_dir}, found {len(scene_dirs)}."
            )
        scene_dir = scene_dirs[0]
        archives = sorted((scene_dir / "downloads").glob("*.zip"))
        if len(archives) != 1:
            raise ValueError(
                f"Cannot recover {role} metadata: expected one downloaded "
                f"HyP3 product ZIP, found {len(archives)}."
            )
        scene_id, _, _ = _read_cached_product_manifest(archives[0])
        acquisition_match = re.search(r"_(\d{8}T\d{6})_", scene_id)
        if acquisition_match is None:
            raise ValueError(
                f"{archives[0]}: source granule has no acquisition timestamp."
            )
        acquired = datetime.strptime(
            acquisition_match.group(1),
            "%Y%m%dT%H%M%S",
        ).replace(tzinfo=timezone.utc)
        if acquired.strftime("%Y%m%d") not in archives[0].stem:
            raise ValueError(
                f"{archives[0]} does not match the acquisition date in its "
                "source granule metadata."
            )

        rasters = {}
        for polarization in ("VV", "VH"):
            candidates = sorted((scene_dir / "cog").glob(f"*_{polarization}.tif"))
            if len(candidates) != 1:
                raise ValueError(
                    f"Cannot recover {role} metadata: expected one {polarization} "
                    f"COG, found {len(candidates)}."
                )
            expected_prefix = archives[0].stem
            if not candidates[0].name.startswith(f"{expected_prefix}_"):
                raise ValueError(
                    f"{candidates[0]} does not match downloaded product "
                    f"{archives[0].name}."
                )
            raster_metadata = _cached_raster_metadata(
                candidates[0],
                project_root=project_root,
            )
            if not all(
                math.isclose(value, 10.0, rel_tol=0.0, abs_tol=0.01)
                for value in raster_metadata["resolution_m"].values()
            ):
                raise ValueError(
                    f"{candidates[0]} does not have the 10 m spacing stated "
                    "in its HyP3 product manifest."
                )
            rasters[polarization] = raster_metadata
        if rasters["VV"]["width"] != rasters["VH"]["width"] or (
            rasters["VV"]["height"] != rasters["VH"]["height"]
        ) or rasters["VV"]["crs"] != rasters["VH"]["crs"] or (
            rasters["VV"]["transform"] != rasters["VH"]["transform"]
        ):
            raise ValueError(
                f"{role} VV and VH COGs are not on the same pixel grid."
            )
        scenes.append(
            {
                "role": role,
                "scene_id": scene_id,
                "acquisition_start_utc": acquired.isoformat(),
                "polarizations": ["VV", "VH"],
                "downloaded_archives": [
                    archives[0]
                    .resolve()
                    .relative_to(project_root.resolve())
                    .as_posix()
                ],
                "product_manifest_verified": True,
                "rasters": rasters,
            }
        )

    before_vv = scenes[0]["rasters"]["VV"]
    after_vv = scenes[1]["rasters"]["VV"]
    return {
        "project": "TERRALENS",
        "provider": "ASF HyP3",
        "metadata_source": "cached COGs and verified HyP3 product manifests",
        "processing": {
            "job_type": "RTC_GAMMA",
            "radiometry": "sigma0",
            "scale": "power",
            "resolution": 10,
            "dem_name": "copernicus",
        },
        "scenes": scenes,
        "pair_alignment": {
            "VV": {
                "native_grids_match": _same_grid_metadata(before_vv, after_vv),
                "reprojection_required": not _same_grid_metadata(
                    before_vv, after_vv
                ),
                "reference_grid": "before",
                "resampling": "nearest",
            }
        },
    }


def _same_grid_metadata(first: dict[str, Any], second: dict[str, Any]) -> bool:
    return (
        first["crs"] == second["crs"]
        and first["width"] == second["width"]
        and first["height"] == second["height"]
        and first["transform"] == second["transform"]
    )


def _validate_processing_metadata(metadata: dict[str, Any]) -> None:
    processing = metadata.get("processing")
    if not isinstance(processing, dict):
        raise ValueError("Scene metadata is missing its 'processing' object.")
    if processing.get("radiometry") != "sigma0":
        raise ValueError(
            "Change detection requires HyP3 RTC Sigma0 radiometry in metadata."
        )
    if processing.get("scale") != "power":
        raise ValueError(
            "Change detection requires linear power scale in metadata; "
            "amplitude-scaled rasters are not supported."
        )


def _find_scene_pair(metadata: dict[str, Any]) -> dict[str, dict[str, str]]:
    scenes_by_role: dict[str, dict[str, str]] = {}
    for scene in metadata["scenes"]:
        if not isinstance(scene, dict):
            raise ValueError("Each entry in metadata 'scenes' must be an object.")
        role = scene.get("role")
        if role not in ("before", "after"):
            continue
        if role in scenes_by_role:
            raise ValueError(f"Scene metadata contains multiple {role!r} scenes.")

        scene_id = scene.get("scene_id")
        acquired = scene.get("acquisition_start_utc")
        rasters = scene.get("rasters")
        vv_raster = rasters.get("VV") if isinstance(rasters, dict) else None
        raster_path = vv_raster.get("path") if isinstance(vv_raster, dict) else None
        if not isinstance(scene_id, str) or not scene_id.strip():
            raise ValueError(f"The {role} scene metadata is missing 'scene_id'.")
        if not isinstance(acquired, str) or not acquired.strip():
            raise ValueError(
                f"The {role} scene metadata is missing 'acquisition_start_utc'."
            )
        if not isinstance(raster_path, str) or not raster_path.strip():
            raise ValueError(
                f"The {role} scene metadata is missing 'rasters.VV.path'."
            )

        scenes_by_role[role] = {
            "role": role,
            "scene_id": scene_id,
            "acquisition_start_utc": acquired,
            "raster_path": raster_path,
        }

    missing = {"before", "after"} - scenes_by_role.keys()
    if missing:
        raise ValueError(
            "Scene metadata must contain one before and one after scene; "
            f"missing {', '.join(sorted(missing))}."
        )
    return scenes_by_role


def _resolve_vv_path(
    metadata_path: str,
    *,
    project_root: Path,
    sar_dir: Path,
    role: str,
) -> Path:
    stored_path = Path(metadata_path)
    if stored_path.is_absolute():
        raster_path = stored_path.resolve()
    else:
        # prepare_sar.py records paths relative to the repository root.
        raster_path = (project_root / stored_path).resolve()

    try:
        raster_path.relative_to(sar_dir.resolve())
    except ValueError as error:
        raise ValueError(
            f"The {role} VV raster path must resolve inside {sar_dir}: "
            f"{metadata_path!r}."
        ) from error
    if not raster_path.is_file():
        raise FileNotFoundError(
            f"The {role} VV COG recorded in metadata does not exist: {raster_path}"
        )
    return raster_path


def _mask_values(mask: np.ndarray, valid: np.ndarray) -> np.ndarray:
    if mask.shape != valid.shape:
        raise ValueError("Water mask and validity mask dimensions do not match.")
    values = np.zeros(mask.shape, dtype=np.uint8)
    values[mask] = 1
    values[~valid] = 255
    return values


def _write_mask(
    path: Path,
    mask: np.ndarray,
    valid: np.ndarray,
    *,
    width: int,
    height: int,
    crs: CRS,
    transform: Affine,
) -> None:
    if mask.shape != (height, width):
        raise ValueError(
            f"Output mask dimensions {mask.shape[::-1]} do not match "
            f"the comparison grid {width}x{height}."
        )
    profile = {
        "driver": "GTiff",
        "width": width,
        "height": height,
        "count": 1,
        "dtype": "uint8",
        "crs": crs,
        "transform": transform,
        "nodata": 255,
        "compress": "deflate",
    }
    with rasterio.open(path, "w", **profile) as dataset:
        dataset.write(_mask_values(mask, valid), 1)


def _pixel_spacing_m(dataset: DatasetReader) -> dict[str, float]:
    if dataset.crs is None:
        raise ValueError(f"{dataset.name}: raster has no CRS.")
    _, unit_to_meters = dataset.crs.linear_units_factor
    transform = dataset.transform
    return {
        "x": math.hypot(transform.a, transform.d) * unit_to_meters,
        "y": math.hypot(transform.b, transform.e) * unit_to_meters,
    }


def _write_outputs(
    output_dir: Path,
    result: ChangeDetectionResult,
    *,
    before_path: Path,
    after_path: Path,
    before_scene: dict[str, str],
    after_scene: dict[str, str],
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    output_paths = {
        "before_water": output_dir / "before_water.tif",
        "after_water": output_dir / "after_water.tif",
        "new_water": output_dir / "new_water.tif",
    }

    with rasterio.open(before_path) as source:
        pixel_spacing_m = _pixel_spacing_m(source)
        before_grid = _dataset_grid_metadata(before_path, source)
    with rasterio.open(after_path) as source:
        after_grid = _dataset_grid_metadata(after_path, source)
    width = result.before_water.shape[1]
    height = result.before_water.shape[0]
    crs, transform = result.crs, result.transform

    _write_mask(
        output_paths["before_water"],
        result.before_water,
        result.before_valid,
        width=width,
        height=height,
        crs=crs,
        transform=transform,
    )
    _write_mask(
        output_paths["after_water"],
        result.after_water,
        result.after_valid,
        width=width,
        height=height,
        crs=crs,
        transform=transform,
    )
    _write_mask(
        output_paths["new_water"],
        result.new_water,
        result.before_valid & result.after_valid,
        width=width,
        height=height,
        crs=crs,
        transform=transform,
    )

    results = {
        "result_type": "observed_new_water_extent",
        "interpretation": "Observed new-water extent, not confirmed flood extent.",
        "new_water_area_km2": result.new_water_area_km2,
        "threshold_db": result.threshold_db,
        "min_component_pixels": result.min_component_pixels,
        "scenes": [
            {
                "role": scene["role"],
                "scene_id": scene["scene_id"],
                "acquisition_start_utc": scene["acquisition_start_utc"],
            }
            for scene in (before_scene, after_scene)
        ],
        "crs": crs.to_string(),
        "pixel_spacing_m": pixel_spacing_m,
        "pixel_area_m2": result.pixel_area_m2,
        "width": width,
        "height": height,
        "comparison_grid": {
            "crs": crs.to_string(),
            "transform": [float(value) for value in transform],
            "bounds": [
                float(value)
                for value in array_bounds(height, width, transform)
            ],
        },
        "input_grids": {
            "before": before_grid,
            "after": after_grid,
        },
        "comparison": {
            "reference_grid": "before",
            "resampling": "nearest-neighbour in linear Sigma0 power",
            "coverage": (
                "Only before-grid pixel centers with valid, finite, positive "
                "power in both scenes are compared; all other output pixels "
                "are nodata."
            ),
            "common_valid_pixels": int(
                np.count_nonzero(result.before_valid & result.after_valid)
            ),
        },
        "outputs": {name: path.name for name, path in output_paths.items()},
    }
    results_path = output_dir / "results.json"
    results_path.write_text(
        json.dumps(results, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return results


def run_change_detection(
    *,
    sar_dir: str | Path = SAR_DIR,
    output_dir: str | Path = OUTPUT_DIR,
    project_root: str | Path = ROOT,
    threshold_db: float = DEFAULT_WATER_THRESHOLD_DB,
    min_component_pixels: int = DEFAULT_MIN_COMPONENT_PIXELS,
) -> dict[str, Any]:
    """Load prepared VV COGs and manifests, compare them, and write outputs."""

    sar_root = Path(sar_dir)
    project_root = Path(project_root)
    metadata_path = sar_root / "metadata.json"
    print(f"Reading prepared scene metadata: {metadata_path}")
    if metadata_path.is_file():
        metadata = _read_metadata(metadata_path)
    else:
        print(
            "metadata.json is missing; verifying scene metadata from cached "
            "HyP3 product manifests."
        )
        metadata = _rebuild_metadata_from_cached_products(
            sar_root,
            project_root=project_root,
        )
    _validate_processing_metadata(metadata)
    scenes = _find_scene_pair(metadata)
    before_scene = scenes["before"]
    after_scene = scenes["after"]
    before_path = _resolve_vv_path(
        before_scene["raster_path"],
        project_root=project_root,
        sar_dir=sar_root,
        role="before",
    )
    after_path = _resolve_vv_path(
        after_scene["raster_path"],
        project_root=project_root,
        sar_dir=sar_root,
        role="after",
    )

    print(
        "Comparing VV RTC scenes: "
        f"{before_scene['scene_id']} -> {after_scene['scene_id']}"
    )
    result = detect_water_change_geospatial(
        before_path,
        after_path,
        threshold_db=threshold_db,
        min_component_pixels=min_component_pixels,
    )
    results = _write_outputs(
        Path(output_dir),
        result,
        before_path=before_path,
        after_path=after_path,
        before_scene=before_scene,
        after_scene=after_scene,
    )

    print(f"Observed new-water area: {result.new_water_area_km2:.6f} km²")
    print(f"Wrote masks and summary to {Path(output_dir)}")
    return results


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Compare the prepared before/after Sentinel-1 VV RTC COGs "
            "listed in cache/sar/metadata.json or verified from local HyP3 ZIPs."
        )
    )
    parser.add_argument(
        "--threshold-db",
        type=float,
        default=DEFAULT_WATER_THRESHOLD_DB,
        help=(
            "Water threshold in dB (default: -15, an initial heuristic rather "
            "than a universal threshold)."
        ),
    )
    parser.add_argument(
        "--min-component-pixels",
        type=int,
        default=DEFAULT_MIN_COMPONENT_PIXELS,
        help="Remove connected water components smaller than this pixel count.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        run_change_detection(
            threshold_db=args.threshold_db,
            min_component_pixels=args.min_component_pixels,
        )
    except (OSError, RasterioError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
