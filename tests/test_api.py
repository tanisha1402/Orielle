from __future__ import annotations

import asyncio
from io import BytesIO
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import httpx
from PIL import Image
import numpy as np
import rasterio
from rasterio.transform import from_bounds, from_origin
from rasterio.warp import transform

from src.api import app


class LocalApiTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.output_dir = Path(self.temporary.name) / "outputs"
        self.output_dir.mkdir()
        self.output_dir_patch = patch("src.api.OUTPUT_DIR", self.output_dir)
        self.output_dir_patch.start()

    def tearDown(self):
        self.output_dir_patch.stop()
        self.temporary.cleanup()

    def test_missing_outputs_return_waiting_and_not_found(self):
        status = self._get("/api/status")
        self.assertEqual(status.status_code, 200)
        self.assertEqual(
            status.json(),
            {
                "status": "waiting_for_sar_processing",
                "missing_outputs": [
                    "results.json",
                    "before_water.tif",
                    "after_water.tif",
                    "new_water.tif",
                ],
            },
        )
        self.assertEqual(self._get("/api/results").status_code, 404)
        self.assertEqual(
            self._get("/tiles/new_water/tiles.json").status_code, 404
        )
        self.assertEqual(self._get("/tiles/new_water/0/0/0.png").status_code, 404)

    def test_serves_results_tilejson_and_transparent_blue_xyz_tile(self):
        results = {
            "result_type": "observed_new_water_extent",
            "new_water_area_km2": 0.001,
            "threshold_db": -15.0,
            "min_component_pixels": 1,
            "pixel_area_m2": 100.0,
            "scenes": [
                {"role": "before", "scene_id": "S1_BEFORE"},
                {"role": "after", "scene_id": "S1_AFTER"},
            ],
        }
        (self.output_dir / "results.json").write_text(
            json.dumps(results), encoding="utf-8"
        )
        mask = np.zeros((256, 256), dtype=np.uint8)
        mask[128, 128] = 1
        for filename in ("before_water.tif", "after_water.tif", "new_water.tif"):
            self._write_mask(self.output_dir / filename, mask)

        status = self._get("/api/status")
        self.assertEqual(status.json(), {"status": "ready", "missing_outputs": []})
        self.assertEqual(self._get("/api/results").json(), results)

        tilejson = self._get("/tiles/new_water/tiles.json")
        self.assertEqual(tilejson.status_code, 200)
        self.assertEqual(
            tilejson.json()["tiles"],
            ["http://testserver/tiles/new_water/{z}/{x}/{y}.png"],
        )
        self.assertEqual(tilejson.json()["scheme"], "xyz")

        tile_response = self._get("/tiles/new_water/0/0/0.png")
        self.assertEqual(tile_response.status_code, 200)
        self.assertEqual(tile_response.headers["content-type"], "image/png")
        image = Image.open(BytesIO(tile_response.content)).convert("RGBA")
        self.assertEqual(image.getpixel((128, 128)), (45, 154, 246, 210))
        self.assertEqual(image.getpixel((0, 0)), (0, 0, 0, 0))

    def test_rejects_out_of_range_xyz_coordinates(self):
        response = self._get("/tiles/new_water/1/2/0.png")
        self.assertEqual(response.status_code, 400)

    def test_reprojects_projected_raster_and_keeps_nodata_transparent(self):
        longitude, latitude = 89.72, 24.45
        x_values, y_values = transform(
            "EPSG:4326",
            "EPSG:32646",
            [longitude],
            [latitude],
        )
        mask = np.full((100, 100), 255, dtype=np.uint8)
        mask[30:70, 30:70] = 1
        with rasterio.open(
            self.output_dir / "new_water.tif",
            "w",
            driver="GTiff",
            width=mask.shape[1],
            height=mask.shape[0],
            count=1,
            dtype="uint8",
            crs="EPSG:32646",
            transform=from_origin(x_values[0] - 500, y_values[0] + 500, 10, 10),
            nodata=255,
        ) as dataset:
            dataset.write(mask, 1)

        zoom = 12
        tile_count = 1 << zoom
        tile_x = int((longitude + 180) / 360 * tile_count)
        latitude_radians = math.radians(latitude)
        tile_y = int(
            (1 - math.asinh(math.tan(latitude_radians)) / math.pi)
            / 2
            * tile_count
        )
        response = self._get(f"/tiles/new_water/{zoom}/{tile_x}/{tile_y}.png")
        self.assertEqual(response.status_code, 200)
        image = np.asarray(Image.open(BytesIO(response.content)).convert("RGBA"))
        blue_pixels = np.all(image == (45, 154, 246, 210), axis=2)
        transparent_pixels = image[:, :, 3] == 0
        self.assertTrue(np.any(blue_pixels))
        self.assertTrue(np.any(transparent_pixels))

    def test_allows_local_vite_origin(self):
        response = self._options(
            "/api/status",
            headers={
                "Origin": "http://localhost:5173",
                "Access-Control-Request-Method": "GET",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:5173",
        )

    @staticmethod
    def _get(path: str) -> httpx.Response:
        async def request() -> httpx.Response:
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport,
                base_url="http://testserver",
            ) as client:
                return await client.get(path)

        return asyncio.run(request())

    @staticmethod
    def _options(path: str, *, headers: dict[str, str]) -> httpx.Response:
        async def request() -> httpx.Response:
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport,
                base_url="http://testserver",
            ) as client:
                return await client.options(path, headers=headers)

        return asyncio.run(request())

    @staticmethod
    def _write_mask(path: Path, mask: np.ndarray) -> None:
        world_limit = 20037508.342789244
        transform = from_bounds(
            -world_limit,
            -world_limit,
            world_limit,
            world_limit,
            mask.shape[1],
            mask.shape[0],
        )
        with rasterio.open(
            path,
            "w",
            driver="GTiff",
            width=mask.shape[1],
            height=mask.shape[0],
            count=1,
            dtype="uint8",
            crs="EPSG:3857",
            transform=transform,
            nodata=255,
        ) as dataset:
            dataset.write(mask, 1)


if __name__ == "__main__":
    unittest.main()
