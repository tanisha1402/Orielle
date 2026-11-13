"""Local API for TERRALENS SAR outputs and training progress."""

from __future__ import annotations

from io import BytesIO
import json
from pathlib import Path
from typing import Any, Literal

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from PIL import Image
import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.errors import RasterioError
from rasterio.transform import from_bounds
from rasterio.vrt import WarpedVRT

from src.gamification.routes import router as gamification_router


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "cache" / "outputs"
TILE_SIZE = 256
WEB_MERCATOR_LIMIT = 20037508.342789244
TileLayer = Literal["before_water", "after_water", "new_water"]

OUTPUT_FILES: dict[str, str] = {
    "results": "results.json",
    "before_water": "before_water.tif",
    "after_water": "after_water.tif",
    "new_water": "new_water.tif",
}
TILE_COLORS: dict[str, tuple[int, int, int, int]] = {
    "before_water": (73, 176, 190, 160),
    "after_water": (118, 166, 229, 160),
    "new_water": (45, 154, 246, 210),
}

app = FastAPI(
    title="TERRALENS local API",
    description=(
        "Read-only SAR outputs and local gamification mission progress."
    ),
    version="1.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)
app.include_router(gamification_router)


def _output_path(name: str) -> Path:
    return OUTPUT_DIR / OUTPUT_FILES[name]


def _load_results() -> dict[str, Any]:
    path = _output_path("results")
    if not path.is_file():
        raise HTTPException(
            status_code=404,
            detail="Change-detection results are not available yet.",
        )
    try:
        results = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to read change-detection results: {error}",
        ) from error
    if not isinstance(results, dict):
        raise HTTPException(
            status_code=500,
            detail="Change-detection results must contain a JSON object.",
        )
    return results


def _require_output(name: str) -> Path:
    path = _output_path(name)
    if not path.is_file():
        raise HTTPException(
            status_code=404,
            detail=f"{OUTPUT_FILES[name]} is not available yet.",
        )
    return path


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/status")
def status(response: Response) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    required = ("results", "before_water", "after_water", "new_water")
    missing = [
        OUTPUT_FILES[name]
        for name in required
        if not _output_path(name).is_file()
    ]
    if missing:
        return {
            "status": "waiting_for_sar_processing",
            "missing_outputs": missing,
        }
    _load_results()
    return {"status": "ready", "missing_outputs": []}


@app.get("/api/results")
def results(response: Response) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    for name in ("before_water", "after_water", "new_water"):
        _require_output(name)
    return _load_results()


@app.get("/tiles/{layer}/tiles.json")
def tilejson(layer: TileLayer, request: Request, response: Response) -> dict[str, Any]:
    response.headers["Cache-Control"] = "no-store"
    _require_output(layer)
    base_url = str(request.base_url).rstrip("/")
    return {
        "tilejson": "3.0.0",
        "name": layer,
        "scheme": "xyz",
        "format": "png",
        "tileSize": TILE_SIZE,
        "minzoom": 0,
        "maxzoom": 22,
        "tiles": [f"{base_url}/tiles/{layer}/{{z}}/{{x}}/{{y}}.png"],
        "bounds": [-180, -85.051129, 180, 85.051129],
        "center": [89.72, 24.45, 8],
    }


@app.get("/tiles/{layer}/{z}/{x}/{y}.png")
def raster_tile(layer: TileLayer, z: int, x: int, y: int) -> Response:
    if z < 0 or z > 22:
        raise HTTPException(status_code=400, detail="Zoom must be between 0 and 22.")
    tile_count = 1 << z
    if x < 0 or y < 0 or x >= tile_count or y >= tile_count:
        raise HTTPException(status_code=400, detail="XYZ tile coordinates are invalid.")

    raster_path = _require_output(layer)
    span = (2 * WEB_MERCATOR_LIMIT) / tile_count
    west = -WEB_MERCATOR_LIMIT + x * span
    north = WEB_MERCATOR_LIMIT - y * span
    tile_transform = from_bounds(
        west,
        north - span,
        west + span,
        north,
        TILE_SIZE,
        TILE_SIZE,
    )

    try:
        with rasterio.open(raster_path) as source:
            if source.count != 1:
                raise HTTPException(
                    status_code=500,
                    detail=f"{OUTPUT_FILES[layer]} must be a single-band mask.",
                )
            with WarpedVRT(
                source,
                crs="EPSG:3857",
                transform=tile_transform,
                width=TILE_SIZE,
                height=TILE_SIZE,
                resampling=Resampling.nearest,
                nodata=255,
            ) as tile:
                values = tile.read(1, masked=True)
    except (OSError, RasterioError, ValueError) as error:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to render {OUTPUT_FILES[layer]} tile: {error}",
        ) from error

    visible_water = (~values.mask) & (values.data == 1)
    rgba = np.zeros((TILE_SIZE, TILE_SIZE, 4), dtype=np.uint8)
    rgba[visible_water] = TILE_COLORS[layer]
    image = Image.fromarray(rgba)
    content = BytesIO()
    image.save(content, format="PNG")
    return Response(
        content=content.getvalue(),
        media_type="image/png",
        headers={"Cache-Control": "no-store"},
    )
