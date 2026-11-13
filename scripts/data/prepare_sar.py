#!/usr/bin/env python
"""Prepare local Sentinel-1 RTC COGs and their per-scene grid metadata."""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

import hyp3_sdk
import rasterio
from hyp3_sdk import HyP3
from hyp3_sdk.exceptions import HyP3Error, HyP3SDKError
from rasterio.errors import RasterioError
from rasterio.shutil import copy as raster_copy
from requests.exceptions import RequestException


BEFORE_SCENE_ID = (
    "S1A_IW_GRDH_1SDV_20200713T120451_20200713T120516_033436_03DFD8_67E8"
)
ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = ROOT / "cache" / "sar"
EXPECTED_POLARIZATIONS = ("VV", "VH")
PIXEL_SPACING_METERS = 10.0
RTC_OPTIONS = {
    "radiometry": "sigma0",
    "resolution": 10,
    "scale": "power",
    "dem_name": "copernicus",
}

SCENE_ID_PATTERN = re.compile(
    r"^(?P<platform>S1[ABCD])_[A-Z0-9]{2}_GRDH_"
    r"1S(?P<polarization_code>DV|DH|SV|SH)_"
    r"(?P<start>\d{8}T\d{6})_(?P<stop>\d{8}T\d{6})_"
    r"(?P<absolute_orbit>\d{6})_[0-9A-F]{6}_[0-9A-F]{4}$",
    re.IGNORECASE,
)
POLARIZATION_PATTERN = re.compile(r"(?:^|[_-])(VV|VH|HH|HV)(?=[_.-]|$)", re.IGNORECASE)


@dataclass(frozen=True)
class Scene:
    scene_id: str
    role: str
    start: datetime
    stop: datetime
    absolute_orbit: int
    polarizations: tuple[str, ...]


def parse_scene_id(scene_id: str, role: str) -> Scene:
    match = SCENE_ID_PATTERN.fullmatch(scene_id)
    if match is None:
        raise ValueError(
            f"Unsupported Sentinel-1 GRD scene ID: {scene_id!r}. "
            "Expected an ESA Sentinel-1 IW/EW/SM/WV GRDH granule ID."
        )

    fields = match.groupdict()
    start = datetime.strptime(fields["start"], "%Y%m%dT%H%M%S").replace(
        tzinfo=timezone.utc
    )
    stop = datetime.strptime(fields["stop"], "%Y%m%dT%H%M%S").replace(
        tzinfo=timezone.utc
    )
    if stop < start:
        raise ValueError(f"Scene stop time precedes start time: {scene_id!r}.")
    polarization_map = {
        "DV": ("VV", "VH"),
        "DH": ("HH", "HV"),
        "SV": ("VV",),
        "SH": ("HH",),
    }
    return Scene(
        scene_id=scene_id,
        role=role,
        start=start,
        stop=stop,
        absolute_orbit=int(fields["absolute_orbit"]),
        polarizations=polarization_map[fields["polarization_code"].upper()],
    )


def make_job_definitions(scenes: list[Scene]) -> list[dict[str, Any]]:
    jobs = []
    for scene in scenes:
        name = f"terralens-jamuna-{scene.role}-{scene.start:%Y%m%d}"
        jobs.append(
            HyP3.prepare_rtc_job(
                granule=scene.scene_id,
                name=name,
                **RTC_OPTIONS,
            )
        )
    return jobs


def _read_raster(path: Path) -> dict[str, Any]:
    with rasterio.open(path) as dataset:
        if dataset.crs is None:
            raise ValueError(f"{path}: raster has no CRS.")
        if (
            not dataset.crs.is_projected
            or dataset.crs.linear_units.lower() not in {"meter", "metre"}
        ):
            raise ValueError(f"{path}: expected a projected CRS with metre units.")
        if dataset.width <= 0 or dataset.height <= 0:
            raise ValueError(f"{path}: raster has invalid dimensions.")
        if dataset.count != 1:
            raise ValueError(f"{path}: expected a single-band polarization raster.")
        if dataset.nodata is None or not math.isfinite(float(dataset.nodata)):
            raise ValueError(f"{path}: raster has no finite nodata value.")

        transform = dataset.transform
        resolution = dataset.res
        if (
            not math.isclose(resolution[0], PIXEL_SPACING_METERS, abs_tol=0.01)
            or not math.isclose(resolution[1], PIXEL_SPACING_METERS, abs_tol=0.01)
            or transform.a <= 0
            or transform.e >= 0
            or not math.isclose(transform.b, 0.0, abs_tol=1e-9)
            or not math.isclose(transform.d, 0.0, abs_tol=1e-9)
        ):
            raise ValueError(
                f"{path}: expected north-up 10 m pixels, got resolution "
                f"{resolution} and transform {transform}."
            )

        return {
            "path": _relative_path(path),
            "crs": dataset.crs.to_string(),
            "resolution_m": [float(resolution[0]), float(resolution[1])],
            "width": dataset.width,
            "height": dataset.height,
            "nodata": float(dataset.nodata),
            "transform": [float(value) for value in transform],
            "dtype": dataset.dtypes[0],
        }


def _relative_path(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return resolved.as_posix()


def _same_grid(first: dict[str, Any], second: dict[str, Any]) -> bool:
    return (
        first["crs"] == second["crs"]
        and first["width"] == second["width"]
        and first["height"] == second["height"]
        and all(
            math.isclose(a, b, rel_tol=0.0, abs_tol=1e-8)
            for a, b in zip(first["transform"], second["transform"])
        )
        and all(
            math.isclose(a, b, rel_tol=0.0, abs_tol=0.01)
            for a, b in zip(first["resolution_m"], second["resolution_m"])
        )
    )


def describe_pair_alignment(
    before: dict[str, dict[str, Any]], after: dict[str, dict[str, Any]]
) -> dict[str, Any]:
    """Validate per-scene VV/VH grids and describe cross-scene alignment needs."""

    for label, rasters in (("before", before), ("after", after)):
        missing = set(EXPECTED_POLARIZATIONS) - set(rasters)
        if missing:
            raise ValueError(
                f"{label} scene is missing required polarization(s): "
                f"{', '.join(sorted(missing))}."
            )
        if not _same_grid(rasters["VV"], rasters["VH"]):
            raise ValueError(f"{label} VV and VH rasters are not pixel-aligned.")

    alignment = {}
    for polarization in EXPECTED_POLARIZATIONS:
        before_grid = before[polarization]
        after_grid = after[polarization]
        native_grids_match = _same_grid(before_grid, after_grid)
        alignment[polarization] = {
            "native_grids_match": native_grids_match,
            "reprojection_required": not native_grids_match,
            "reference_grid": "before",
            "resampling": "nearest",
            "before_grid": before_grid,
            "after_grid": after_grid,
        }
    return alignment


def _is_cog(path: Path) -> bool:
    with rasterio.open(path) as dataset:
        return dataset.tags(ns="IMAGE_STRUCTURE").get("LAYOUT") == "COG"


def _make_cog(source: Path, destination: Path) -> Path:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if _is_cog(source):
        shutil.copy2(source, destination)
    else:
        raster_copy(
            source,
            destination,
            driver="COG",
            compress="DEFLATE",
            blocksize=512,
            overview_resampling="AVERAGE",
        )
    if not _is_cog(destination):
        raise RasterioError(f"COG validation failed for {destination}.")
    return destination


def _extract_geotiffs(archive: Path, destination: Path) -> list[Path]:
    destination.mkdir(parents=True, exist_ok=True)
    extracted = []
    with zipfile.ZipFile(archive) as product:
        for member in product.infolist():
            if member.is_dir() or Path(member.filename).suffix.lower() not in {
                ".tif",
                ".tiff",
            }:
                continue
            filename = PurePosixPath(member.filename.replace("\\", "/")).name
            target = destination / filename
            if target.exists():
                raise FileExistsError(
                    f"Refusing to overwrite an existing product raster: {target}"
                )
            with product.open(member) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)
            extracted.append(target)
    return extracted


def _downloaded_rasters(job: Any, scene_dir: Path) -> tuple[list[Path], list[str]]:
    download_dir = scene_dir / "downloads"
    product_dir = scene_dir / "products"
    downloaded = job.download_files(location=download_dir)
    if not downloaded:
        raise RuntimeError(f"HyP3 returned no downloadable products for {job.job_id}.")

    rasters: list[Path] = []
    archives = []
    for product_path in downloaded:
        path = Path(product_path)
        if zipfile.is_zipfile(path):
            archives.append(_relative_path(path))
            rasters.extend(_extract_geotiffs(path, product_dir))
        elif path.suffix.lower() in {".tif", ".tiff"}:
            product_dir.mkdir(parents=True, exist_ok=True)
            target = product_dir / path.name
            if target.exists():
                raise FileExistsError(
                    f"Refusing to overwrite an existing product raster: {target}"
                )
            shutil.copy2(path, target)
            rasters.append(target)
        else:
            raise RuntimeError(
                f"Unrecognized HyP3 download product: {path.name}. "
                "Expected a product ZIP or GeoTIFF."
            )
    return rasters, archives


def _polarization_rasters(paths: list[Path]) -> dict[str, Path]:
    found: dict[str, list[Path]] = {polarization: [] for polarization in EXPECTED_POLARIZATIONS}
    for path in paths:
        match = POLARIZATION_PATTERN.search(path.name)
        if match is not None and match.group(1).upper() in found:
            found[match.group(1).upper()].append(path)

    selected = {}
    for polarization, candidates in found.items():
        if len(candidates) != 1:
            names = ", ".join(candidate.name for candidate in candidates) or "none"
            raise RuntimeError(
                f"Expected exactly one {polarization} GeoTIFF in the HyP3 product; "
                f"found {len(candidates)} ({names})."
            )
        selected[polarization] = candidates[0]
    return selected


def _prepare_scene(scene: Scene, job: Any) -> dict[str, Any]:
    scene_dir = CACHE_DIR / f"{scene.role}-{scene.start:%Y%m%d}-{job.job_id}"
    rasters, archives = _downloaded_rasters(job, scene_dir)
    source_by_polarization = _polarization_rasters(rasters)

    raster_metadata = {}
    for polarization, source in source_by_polarization.items():
        cog = _make_cog(source, scene_dir / "cog" / source.name)
        raster_metadata[polarization] = _read_raster(cog)

    return {
        "role": scene.role,
        "scene_id": scene.scene_id,
        "acquisition_start_utc": scene.start.isoformat(),
        "acquisition_stop_utc": scene.stop.isoformat(),
        "absolute_orbit": scene.absolute_orbit,
        "polarizations": list(source_by_polarization),
        "hyP3_job_id": job.job_id,
        "hyP3_status": job.status_code,
        "downloaded_archives": archives,
        "rasters": raster_metadata,
    }


def _write_metadata(metadata: dict[str, Any]) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    target = CACHE_DIR / "metadata.json"
    temporary = target.with_suffix(".json.tmp")
    temporary.write_text(
        json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    temporary.replace(target)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Submit two ASF HyP3 Sentinel-1 RTC jobs for the Jamuna River, "
            "download their products, and prepare local VV/VH COGs."
        )
    )
    parser.add_argument(
        "--after-scene",
        required=True,
        help="ESA Sentinel-1 GRDH granule ID acquired after the fixed before-scene.",
    )
    parser.add_argument(
        "--auth",
        choices=("token", "netrc"),
        default="token",
        help="Use a masked Earthdata token prompt (default) or SDK .netrc lookup.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print SDK-prepared HyP3 job requests without authentication or network access.",
    )
    parser.add_argument(
        "--confirm-submit",
        action="store_true",
        help="Explicitly authorize submitting two publicly visible HyP3 processing jobs.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=10800,
        help="Maximum time to monitor jobs (default: 10800 seconds).",
    )
    parser.add_argument(
        "--poll-interval-seconds",
        type=int,
        default=60,
        help="Seconds between job status checks (default: 60).",
    )
    return parser


def _validate_args(args: argparse.Namespace, parser: argparse.ArgumentParser) -> list[Scene]:
    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be greater than zero.")
    if args.poll_interval_seconds <= 0:
        parser.error("--poll-interval-seconds must be greater than zero.")
    if not args.dry_run and not args.confirm_submit:
        parser.error(
            "Live execution requires --confirm-submit. Use --dry-run to inspect "
            "the requests without submitting jobs."
        )

    before = parse_scene_id(BEFORE_SCENE_ID, "before")
    after = parse_scene_id(args.after_scene, "after")
    if after.start <= before.start:
        parser.error("--after-scene must have an acquisition start later than the before-scene.")
    for scene in (before, after):
        if not set(EXPECTED_POLARIZATIONS).issubset(scene.polarizations):
            parser.error(
                f"{scene.role} scene must be dual VV/VH polarized; "
                f"{scene.scene_id} declares {', '.join(scene.polarizations)}."
            )
    return [before, after]


def _dry_run(scenes: list[Scene], jobs: list[dict[str, Any]]) -> int:
    print("Dry run: no credentials requested and no network calls made.")
    print(json.dumps(jobs, indent=2))
    print(f"Planned scenes: {', '.join(scene.scene_id for scene in scenes)}")
    print(
        "Live execution submits two publicly visible HyP3 jobs and may use "
        "processing credits; it requires --confirm-submit."
    )
    return 0


def run(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    scenes = _validate_args(args, parser)
    jobs = make_job_definitions(scenes)
    if args.dry_run:
        return _dry_run(scenes, jobs)

    print("Submitting the following RTC jobs to ASF HyP3:")
    for scene in scenes:
        print(f"  {scene.role}: {scene.scene_id}")
    print(
        "Options: sigma0 radiometry, power scale, 10 m output, "
        "Copernicus GLO-30 DEM."
    )
    print(
        "HyP3 jobs are publicly visible and may consume processing credits. "
        "Continuing because --confirm-submit was provided."
    )

    hyp3 = HyP3(prompt="token") if args.auth == "token" else HyP3()
    print("Submitting two RTC jobs...")
    batch = hyp3.submit_prepared_jobs(prepared_jobs=jobs)
    if len(batch.jobs) != len(scenes):
        raise RuntimeError(
            f"Expected {len(scenes)} submitted jobs, received {len(batch.jobs)}."
        )
    print("Monitoring HyP3 processing...")
    completed = hyp3.watch(
        batch,
        timeout=args.timeout_seconds,
        interval=args.poll_interval_seconds,
    )
    failed = [job for job in completed.jobs if not job.succeeded()]
    if failed:
        details = "; ".join(
            f"{job.job_id}: {job.status_code}" for job in failed
        )
        raise RuntimeError(f"HyP3 processing failed: {details}")

    jobs_by_name = {job.name: job for job in completed.jobs}
    expected_names = {job["name"] for job in jobs}
    if len(jobs_by_name) != len(completed.jobs) or set(jobs_by_name) != expected_names:
        raise RuntimeError(
            "The completed HyP3 jobs did not match the two submitted job names."
        )

    scene_results = []
    scene_rasters = []
    for scene, job_definition in zip(scenes, jobs):
        job = jobs_by_name[job_definition["name"]]
        print(f"Downloading {scene.role} scene products...")
        result = _prepare_scene(scene, job)
        scene_results.append(result)
        scene_rasters.append(result["rasters"])

    alignment = describe_pair_alignment(scene_rasters[0], scene_rasters[1])
    metadata = {
        "project": "TERRALENS",
        "study_area": "Jamuna River, Bangladesh",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "provider": "ASF HyP3",
        "hyp3_sdk_version": hyp3_sdk.__version__,
        "processing": {
            "job_type": "RTC_GAMMA",
            **RTC_OPTIONS,
        },
        "scenes": scene_results,
        "pair_alignment": alignment,
    }
    _write_metadata(metadata)
    print(
        "Prepared per-scene aligned VV/VH COGs and recorded the native "
        f"before/after grids at {CACHE_DIR}."
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        return run(args, parser)
    except (
        HyP3Error,
        HyP3SDKError,
        OSError,
        RasterioError,
        RequestException,
        ValueError,
        RuntimeError,
        zipfile.BadZipFile,
    ) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
