"""Threshold-based change detection for Sentinel-1 RTC power rasters.

The default -15 dB water threshold is an initial heuristic, not a universal
constant. Vegetation, urban double-bounce, soil moisture, and other surface
conditions can change radar backscatter independently of open water. Results
represent observed new-water extent, not confirmed flooding; review the
threshold and validate detections against independent evidence.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path

import numpy as np
import rasterio
from affine import Affine
from rasterio.crs import CRS
from rasterio.enums import Resampling
from rasterio.errors import RasterioError
from rasterio.warp import transform_bounds
from rasterio.windows import Window
from rasterio.vrt import WarpedVRT
from scipy import ndimage


DEFAULT_WATER_THRESHOLD_DB = -15.0
DEFAULT_MIN_COMPONENT_PIXELS = 1
_EIGHT_CONNECTED = np.ones((3, 3), dtype=np.uint8)
_SUPPORTED_METRIC_UNITS = {
    "meter",
    "meters",
    "metre",
    "metres",
    "kilometer",
    "kilometers",
    "kilometre",
    "kilometres",
    "centimeter",
    "centimeters",
    "centimetre",
    "centimetres",
    "millimeter",
    "millimeters",
    "millimetre",
    "millimetres",
}


@dataclass(frozen=True)
class ChangeDetectionResult:
    """Masks and measurements from a before/after RTC comparison.

    Water masks are threshold-derived observations, not proof of flooding.
    """

    before_db: np.ndarray
    after_db: np.ndarray
    before_valid: np.ndarray
    after_valid: np.ndarray
    before_water: np.ndarray
    after_water: np.ndarray
    new_water: np.ndarray
    new_water_area_km2: float
    pixel_area_m2: float
    threshold_db: float
    min_component_pixels: int
    crs: CRS
    transform: Affine


@dataclass(frozen=True)
class _Raster:
    power: np.ndarray
    valid: np.ndarray
    crs: CRS
    transform: Affine
    width: int
    height: int


def power_to_db(
    power: np.ndarray, valid_mask: np.ndarray | None = None
) -> np.ndarray:
    """Convert positive linear power to dB; invalid values are returned as NaN.

    The conversion is ``10 * log10(power)``. Zero, negative, NaN, infinity,
    and any pixels excluded by ``valid_mask`` are never converted.
    """

    values = np.asarray(power)
    if (
        values.ndim != 2
        or not np.issubdtype(values.dtype, np.number)
        or np.issubdtype(values.dtype, np.complexfloating)
    ):
        raise ValueError("Power input must be a two-dimensional numeric array.")

    valid = np.isfinite(values) & (values > 0)
    if valid_mask is not None:
        supplied_mask = np.asarray(valid_mask, dtype=bool)
        if supplied_mask.shape != values.shape:
            raise ValueError("valid_mask shape must match the power array.")
        valid &= supplied_mask

    result = np.full(values.shape, np.nan, dtype=np.float64)
    result[valid] = 10.0 * np.log10(values[valid].astype(np.float64))
    return result


def remove_small_components(
    water_mask: np.ndarray, min_component_pixels: int
) -> np.ndarray:
    """Remove water components smaller than a pixel-count threshold.

    Components use 8-neighbour connectivity. A minimum of 1 preserves all
    components; choose a larger value only when justified for the study area.
    """

    if (
        isinstance(min_component_pixels, bool)
        or not isinstance(min_component_pixels, (int, np.integer))
        or min_component_pixels < 1
    ):
        raise ValueError("min_component_pixels must be a positive integer.")

    mask = np.asarray(water_mask, dtype=bool)
    if mask.ndim != 2:
        raise ValueError("water_mask must be a two-dimensional array.")

    labels, component_count = ndimage.label(mask, structure=_EIGHT_CONNECTED)
    if component_count == 0 or min_component_pixels == 1:
        return mask.copy()

    component_sizes = np.bincount(labels.ravel(), minlength=component_count + 1)
    keep = component_sizes >= min_component_pixels
    keep[0] = False
    return keep[labels]


def calculate_area_km2(
    mask: np.ndarray, transform: Affine, crs: CRS | str
) -> float:
    """Calculate masked pixel area in km² using an affine grid and metric CRS.

    Projected metric units supported by the CRS are converted to metres.
    Geographic coordinate systems and non-metric projected units are rejected.
    """

    selected = np.asarray(mask, dtype=bool)
    if selected.ndim != 2:
        raise ValueError("Area mask must be a two-dimensional array.")

    pixel_area_m2 = _pixel_area_m2(transform, CRS.from_user_input(crs))
    return float(np.count_nonzero(selected) * pixel_area_m2 / 1_000_000.0)


def _pixel_area_m2(transform: Affine, coordinate_system: CRS) -> float:
    if not coordinate_system.is_projected:
        raise ValueError(
            "Area calculation requires a projected CRS with metric units; "
            f"got {coordinate_system}."
        )

    unit_name, unit_to_meters = coordinate_system.linear_units_factor
    if (
        unit_name.casefold() not in _SUPPORTED_METRIC_UNITS
        or not math.isfinite(unit_to_meters)
        or unit_to_meters <= 0
    ):
        raise ValueError(
            "Area calculation requires supported metric pixel units; "
            f"got {unit_name!r}."
        )

    coefficients = (transform.a, transform.b, transform.d, transform.e)
    if not all(math.isfinite(value) for value in coefficients):
        raise ValueError("Affine transform must contain finite pixel dimensions.")
    pixel_area_in_crs_units = abs(
        transform.a * transform.e - transform.b * transform.d
    )
    if not math.isfinite(pixel_area_in_crs_units) or pixel_area_in_crs_units <= 0:
        raise ValueError("Affine transform has zero or invalid pixel area.")

    return pixel_area_in_crs_units * unit_to_meters**2


def _read_rtc(path: str | Path) -> _Raster:
    raster_path = Path(path)
    try:
        with rasterio.open(raster_path) as dataset:
            if dataset.count != 1:
                raise ValueError(
                    f"{raster_path}: expected a single-band RTC GeoTIFF, "
                    f"found {dataset.count} bands."
                )
            if dataset.crs is None:
                raise ValueError(f"{raster_path}: raster has no CRS.")

            masked_power = dataset.read(1, masked=True)
            power = np.asarray(masked_power.data)
            valid = (
                ~np.ma.getmaskarray(masked_power)
                & np.isfinite(power)
                & (power > 0)
            )
            return _Raster(
                power=power,
                valid=valid,
                crs=dataset.crs,
                transform=dataset.transform,
                width=dataset.width,
                height=dataset.height,
            )
    except RasterioError as error:
        raise ValueError(f"Unable to read RTC GeoTIFF {raster_path}: {error}") from error


def _valid_pixels(masked_power: np.ma.MaskedArray) -> tuple[np.ndarray, np.ndarray]:
    power = np.asarray(masked_power.data)
    valid = (
        ~np.ma.getmaskarray(masked_power)
        & np.isfinite(power)
        & (power > 0)
    )
    return power, valid


def _validate_matching_grid(before: _Raster, after: _Raster) -> None:
    if before.crs != after.crs:
        raise ValueError(
            f"Before/after CRS differ: {before.crs} != {after.crs}."
        )
    if (before.width, before.height) != (after.width, after.height):
        raise ValueError(
            "Before/after raster dimensions differ: "
            f"{before.width}x{before.height} != {after.width}x{after.height}."
        )
    if before.transform != after.transform:
        raise ValueError(
            "Before/after affine transforms differ; pixel grids are not aligned."
        )


def _validate_parameters(threshold_db: float, min_component_pixels: int) -> None:
    if (
        isinstance(threshold_db, (bool, complex, np.complexfloating))
        or not isinstance(threshold_db, (int, float, np.number))
        or not math.isfinite(threshold_db)
    ):
        raise ValueError("threshold_db must be a finite value in dB.")
    if (
        isinstance(min_component_pixels, bool)
        or not isinstance(min_component_pixels, (int, np.integer))
        or min_component_pixels < 1
    ):
        raise ValueError("min_component_pixels must be a positive integer.")


def _classify_aligned(
    before: _Raster,
    after: _Raster,
    *,
    threshold_db: float,
    min_component_pixels: int,
) -> ChangeDetectionResult:
    _validate_matching_grid(before, after)
    before_db = power_to_db(before.power, before.valid)
    after_db = power_to_db(after.power, after.valid)
    before_water = remove_small_components(
        before.valid & (before_db <= threshold_db), min_component_pixels
    )
    after_water = remove_small_components(
        after.valid & (after_db <= threshold_db), min_component_pixels
    )
    paired_valid = before.valid & after.valid
    new_water = after_water & ~before_water & paired_valid
    pixel_area_m2 = _pixel_area_m2(before.transform, before.crs)
    area = float(np.count_nonzero(new_water) * pixel_area_m2 / 1_000_000.0)

    return ChangeDetectionResult(
        before_db=before_db,
        after_db=after_db,
        before_valid=before.valid,
        after_valid=after.valid,
        before_water=before_water,
        after_water=after_water,
        new_water=new_water,
        new_water_area_km2=area,
        pixel_area_m2=pixel_area_m2,
        threshold_db=float(threshold_db),
        min_component_pixels=int(min_component_pixels),
        crs=before.crs,
        transform=before.transform,
    )


def _common_reference_window(
    before: rasterio.io.DatasetReader,
    after: rasterio.io.DatasetReader,
) -> Window:
    """Return a before-grid window around the transformed raster-bound overlap."""

    try:
        after_bounds = transform_bounds(
            after.crs,
            before.crs,
            *after.bounds,
            densify_pts=101,
        )
    except (RasterioError, ValueError) as error:
        raise ValueError(
            f"Unable to transform after-scene bounds into {before.crs}."
        ) from error

    before_bounds = before.bounds
    left = max(before_bounds.left, after_bounds[0])
    bottom = max(before_bounds.bottom, after_bounds[1])
    right = min(before_bounds.right, after_bounds[2])
    top = min(before_bounds.top, after_bounds[3])
    if left >= right or bottom >= top:
        raise ValueError(
            "Before and after RTC rasters have no geographic bounding-box overlap."
        )

    inverse = ~before.transform
    pixel_corners = [
        inverse @ (x, y)
        for x, y in (
            (left, bottom),
            (left, top),
            (right, bottom),
            (right, top),
        )
    ]
    col_start = max(0, math.floor(min(col for col, _ in pixel_corners)))
    row_start = max(0, math.floor(min(row for _, row in pixel_corners)))
    col_stop = min(before.width, math.ceil(max(col for col, _ in pixel_corners)))
    row_stop = min(before.height, math.ceil(max(row for _, row in pixel_corners)))
    if col_start >= col_stop or row_start >= row_stop:
        raise ValueError(
            "Before and after RTC rasters have no overlap on the before-scene grid."
        )
    return Window(
        col_off=col_start,
        row_off=row_start,
        width=col_stop - col_start,
        height=row_stop - row_start,
    )


def detect_water_change(
    before_path: str | Path,
    after_path: str | Path,
    *,
    threshold_db: float = DEFAULT_WATER_THRESHOLD_DB,
    min_component_pixels: int = DEFAULT_MIN_COMPONENT_PIXELS,
) -> ChangeDetectionResult:
    """Detect threshold-derived observed new-water extent between two RTC rasters.

    Inputs must be single-band, aligned GeoTIFFs containing linear sigma0
    power. Positive valid pixels are converted to dB and classified as water
    when at or below ``threshold_db``. The default -15 dB is an initial
    heuristic, not a universal threshold. Vegetation, urban double-bounce,
    soil moisture, and threshold uncertainty can affect classification; this
    output is observed new-water extent, not confirmed flood area.

    Before/after masks are component-filtered independently using 8-neighbour
    connectivity. ``new_water`` only includes pixels valid in both scenes, so
    missing observations are not misreported as new water.
    """

    _validate_parameters(threshold_db, min_component_pixels)

    before = _read_rtc(before_path)
    after = _read_rtc(after_path)
    _validate_matching_grid(before, after)

    return _classify_aligned(
        before,
        after,
        threshold_db=threshold_db,
        min_component_pixels=min_component_pixels,
    )


def detect_water_change_geospatial(
    before_path: str | Path,
    after_path: str | Path,
    *,
    threshold_db: float = DEFAULT_WATER_THRESHOLD_DB,
    min_component_pixels: int = DEFAULT_MIN_COMPONENT_PIXELS,
) -> ChangeDetectionResult:
    """Align the after RTC to the before grid and compare only shared coverage.

    The after-scene's linear Sigma0 power is reprojected with nearest-neighbour
    sampling. The target grid is cropped to the transformed raster-bounds
    intersection, then valid pixels from both scenes define the comparison
    coverage. Pixels outside that shared coverage remain invalid; they are
    never treated as non-water. Component filtering is performed within the
    shared coverage, so components cut by its boundary may be smaller than
    their full-scene counterparts.

    Use :func:`detect_water_change` instead when inputs are required to already
    share an identical grid; that function continues to reject grid mismatch.
    """

    _validate_parameters(threshold_db, min_component_pixels)
    before_raster_path = Path(before_path)
    after_raster_path = Path(after_path)
    try:
        with rasterio.open(before_raster_path) as before_dataset:
            with rasterio.open(after_raster_path) as after_dataset:
                for path, dataset in (
                    (before_raster_path, before_dataset),
                    (after_raster_path, after_dataset),
                ):
                    if dataset.count != 1:
                        raise ValueError(
                            f"{path}: expected a single-band RTC GeoTIFF, "
                            f"found {dataset.count} bands."
                        )
                    if dataset.crs is None:
                        raise ValueError(f"{path}: raster has no CRS.")

                window = _common_reference_window(
                    before_dataset,
                    after_dataset,
                )
                width, height = int(window.width), int(window.height)
                target_transform = before_dataset.window_transform(window)
                before_power, before_valid = _valid_pixels(
                    before_dataset.read(1, window=window, masked=True)
                )

                with WarpedVRT(
                    after_dataset,
                    crs=before_dataset.crs,
                    transform=target_transform,
                    width=width,
                    height=height,
                    resampling=Resampling.nearest,
                    nodata=0.0,
                ) as aligned_after:
                    after_power, after_valid = _valid_pixels(
                        aligned_after.read(1, masked=True)
                    )

                common_valid = before_valid & after_valid
                if not np.any(common_valid):
                    raise ValueError(
                        "The rasters' geographic extents overlap, but there "
                        "are no valid shared pixel centers."
                    )

                before = _Raster(
                    power=before_power,
                    valid=common_valid,
                    crs=before_dataset.crs,
                    transform=target_transform,
                    width=width,
                    height=height,
                )
                after = _Raster(
                    power=after_power,
                    valid=common_valid,
                    crs=before_dataset.crs,
                    transform=target_transform,
                    width=width,
                    height=height,
                )
    except RasterioError as error:
        raise ValueError(
            f"Unable to read or align RTC GeoTIFFs: {error}"
        ) from error

    return _classify_aligned(
        before,
        after,
        threshold_db=threshold_db,
        min_component_pixels=min_component_pixels,
    )
