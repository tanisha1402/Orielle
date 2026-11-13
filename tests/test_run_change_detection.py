import json
import tempfile
import unittest
from pathlib import Path
import zipfile

import numpy as np
import rasterio
from rasterio.transform import from_origin

from scripts.data.run_change_detection import run_change_detection


class RunChangeDetectionTests(unittest.TestCase):
    def test_reads_prepared_metadata_and_writes_georeferenced_masks(self):
        before = np.array(
            [
                [0.1, 0.1, 0.1, 0.1],
                [0.1, 0.01, 0.1, 0.1],
                [0.1, 0.1, 0.1, -9999],
            ],
            dtype=np.float32,
        )
        after = np.array(
            [
                [0.1, 0.01, 0.1, 0.1],
                [0.1, 0.01, 0.1, 0.01],
                [0.1, 0.1, 0.1, 0.01],
            ],
            dtype=np.float32,
        )

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sar_dir = root / "cache" / "sar"
            before_path = sar_dir / "before" / "cog" / "before-vv.tif"
            after_path = sar_dir / "after" / "cog" / "after-vv.tif"
            before_path.parent.mkdir(parents=True)
            after_path.parent.mkdir(parents=True)
            self._write_raster(before_path, before, nodata=-9999)
            self._write_raster(after_path, after, nodata=-9999)
            self._write_metadata(root, before_path, after_path)

            results = run_change_detection(
                sar_dir=sar_dir,
                output_dir=root / "cache" / "outputs",
                project_root=root,
                threshold_db=-15,
                min_component_pixels=1,
            )

            output_dir = root / "cache" / "outputs"
            self.assertAlmostEqual(results["new_water_area_km2"], 0.0002)
            self.assertEqual(results["threshold_db"], -15)
            self.assertEqual(results["min_component_pixels"], 1)
            self.assertEqual(
                results["scenes"],
                [
                    {
                        "role": "before",
                        "scene_id": "S1A_BEFORE",
                        "acquisition_start_utc": "2020-07-13T12:04:51+00:00",
                    },
                    {
                        "role": "after",
                        "scene_id": "S1A_AFTER",
                        "acquisition_start_utc": "2020-07-25T12:04:51+00:00",
                    },
                ],
            )
            self.assertEqual(results["crs"], "EPSG:32646")
            self.assertEqual(results["pixel_spacing_m"], {"x": 10.0, "y": 10.0})

            expected_masks = {
                "before_water.tif": np.array(
                    [[0, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 255]],
                    dtype=np.uint8,
                ),
                "after_water.tif": np.array(
                    [[0, 1, 0, 0], [0, 1, 0, 1], [0, 0, 0, 255]],
                    dtype=np.uint8,
                ),
                "new_water.tif": np.array(
                    [[0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 0, 255]],
                    dtype=np.uint8,
                ),
            }
            for filename, expected in expected_masks.items():
                with rasterio.open(output_dir / filename) as dataset:
                    self.assertEqual(dataset.width, 4)
                    self.assertEqual(dataset.height, 3)
                    self.assertEqual(dataset.crs.to_string(), "EPSG:32646")
                    self.assertEqual(
                        dataset.transform,
                        from_origin(500000, 2700000, 10, 10),
                    )
                    self.assertEqual(dataset.nodata, 255)
                    np.testing.assert_array_equal(dataset.read(1), expected)

            saved_results = json.loads(
                (output_dir / "results.json").read_text(encoding="utf-8")
            )
            self.assertEqual(saved_results, results)

    def test_recovers_missing_metadata_from_cached_hyp3_manifests(self):
        before = np.full((4, 4), 0.1, dtype=np.float32)
        after = np.full((3, 3), 0.01, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sar_dir = root / "cache" / "sar"
            scenes = (
                (
                    "before-20200713-existing",
                    "S1A_IW_GRDH_1SDV_20200713T120451_20200713T120516_033436_03DFD8_67E8",
                    "S1A_IW_20200713T120451_DVP_RTC10_G_spuned_1AC7",
                    before,
                ),
                (
                    "after-20200730-existing",
                    "S1A_IW_GRDH_1SDV_20200730T121259_20200730T121324_033684_03E765_4001",
                    "S1A_IW_20200730T121259_DVP_RTC10_G_spuned_4446",
                    after,
                ),
            )
            for directory, scene_id, product_id, values in scenes:
                scene_dir = sar_dir / directory
                cog_dir = scene_dir / "cog"
                downloads = scene_dir / "downloads"
                cog_dir.mkdir(parents=True)
                downloads.mkdir()
                for polarization in ("VV", "VH"):
                    self._write_raster(
                        cog_dir / f"{product_id}_{polarization}.tif",
                        values,
                        nodata=0,
                        transform=(
                            from_origin(500010, 2700030, 10, 10)
                            if directory.startswith("after-")
                            else from_origin(500000, 2700040, 10, 10)
                        ),
                    )
                readme = (
                    "These products have been processed to output sigma-0 power. "
                    "They have a pixel spacing of 10 meters.\n"
                    "The source granule used to generate the products contained "
                    f"in this folder is:\n{scene_id}\n"
                )
                log = "Radiometry : sigma0\nDEM name : copernicus\n"
                with zipfile.ZipFile(
                    downloads / f"{product_id}.zip",
                    "w",
                    compression=zipfile.ZIP_DEFLATED,
                ) as archive:
                    archive.writestr(
                        f"{product_id}/{product_id}.README.md.txt",
                        readme,
                    )
                    archive.writestr(f"{product_id}/{product_id}.log", log)

            results = run_change_detection(
                sar_dir=sar_dir,
                output_dir=root / "cache" / "outputs",
                project_root=root,
            )

            self.assertEqual(results["scenes"][0]["scene_id"], scenes[0][1])
            self.assertEqual(results["scenes"][1]["scene_id"], scenes[1][1])
            self.assertEqual(results["comparison"]["common_valid_pixels"], 9)
            self.assertEqual((results["width"], results["height"]), (3, 3))
            self.assertEqual(
                results["comparison_grid"]["transform"],
                list(from_origin(500010, 2700030, 10, 10)),
            )
            for output_name in (
                "before_water.tif",
                "after_water.tif",
                "new_water.tif",
            ):
                with rasterio.open(
                    root / "cache" / "outputs" / output_name
                ) as output:
                    self.assertEqual((output.width, output.height), (3, 3))
                    self.assertEqual(
                        output.transform,
                        from_origin(500010, 2700030, 10, 10),
                    )
            self.assertFalse((sar_dir / "metadata.json").exists())

    def test_rejects_vv_raster_path_outside_sar_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sar_dir = root / "cache" / "sar"
            sar_dir.mkdir(parents=True)
            metadata = {
                "processing": {
                    "radiometry": "sigma0",
                    "scale": "power",
                },
                "scenes": [
                    self._scene("before", "cache/outside.tif"),
                    self._scene("after", "cache/sar/after.tif"),
                ]
            }
            (sar_dir / "metadata.json").write_text(
                json.dumps(metadata), encoding="utf-8"
            )

            with self.assertRaisesRegex(ValueError, "inside"):
                run_change_detection(
                    sar_dir=sar_dir,
                    output_dir=root / "cache" / "outputs",
                    project_root=root,
                )

    def test_rejects_amplitude_scaled_processing_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sar_dir = root / "cache" / "sar"
            sar_dir.mkdir(parents=True)
            metadata = {
                "processing": {
                    "radiometry": "sigma0",
                    "scale": "amplitude",
                },
                "scenes": [
                    self._scene("before", "cache/sar/before.tif"),
                    self._scene("after", "cache/sar/after.tif"),
                ],
            }
            (sar_dir / "metadata.json").write_text(
                json.dumps(metadata), encoding="utf-8"
            )

            with self.assertRaisesRegex(ValueError, "linear power"):
                run_change_detection(
                    sar_dir=sar_dir,
                    output_dir=root / "cache" / "outputs",
                    project_root=root,
                )

    @classmethod
    def _write_metadata(
        cls, root: Path, before_path: Path, after_path: Path
    ) -> None:
        metadata = {
            "project": "TERRALENS",
            "provider": "ASF HyP3",
            "processing": {
                "job_type": "RTC_GAMMA",
                "radiometry": "sigma0",
                "resolution": 10,
                "scale": "power",
                "dem_name": "copernicus",
            },
            "scenes": [
                cls._scene(
                    "before",
                    before_path.relative_to(root).as_posix(),
                    "S1A_BEFORE",
                    "2020-07-13T12:04:51+00:00",
                ),
                cls._scene(
                    "after",
                    after_path.relative_to(root).as_posix(),
                    "S1A_AFTER",
                    "2020-07-25T12:04:51+00:00",
                ),
            ],
            "pair_alignment": {
                "VV": {
                    "validated": True,
                    "crs": "EPSG:32646",
                    "width": 4,
                    "height": 3,
                    "resolution_m": [10.0, 10.0],
                }
            },
        }
        (root / "cache" / "sar" / "metadata.json").write_text(
            json.dumps(metadata), encoding="utf-8"
        )

    @staticmethod
    def _scene(
        role: str,
        raster_path: str,
        scene_id: str | None = None,
        acquired: str | None = None,
    ) -> dict[str, object]:
        default_id = "S1A_BEFORE" if role == "before" else "S1A_AFTER"
        default_date = (
            "2020-07-13T12:04:51+00:00"
            if role == "before"
            else "2020-07-25T12:04:51+00:00"
        )
        return {
            "role": role,
            "scene_id": scene_id or default_id,
            "acquisition_start_utc": acquired or default_date,
            "rasters": {
                "VV": {
                    "path": raster_path,
                    "crs": "EPSG:32646",
                    "resolution_m": [10.0, 10.0],
                    "width": 4,
                    "height": 3,
                    "nodata": -9999.0,
                    "transform": [
                        10.0,
                        0.0,
                        500000.0,
                        0.0,
                        -10.0,
                        2700000.0,
                    ],
                    "dtype": "float32",
                }
            },
        }

    @staticmethod
    def _write_raster(
        path: Path,
        values: np.ndarray,
        *,
        nodata: float,
        transform=None,
    ) -> None:
        if transform is None:
            transform = from_origin(500000, 2700000, 10, 10)
        with rasterio.open(
            path,
            "w",
            driver="GTiff",
            width=values.shape[1],
            height=values.shape[0],
            count=1,
            dtype=values.dtype,
            crs="EPSG:32646",
            transform=transform,
            nodata=nodata,
        ) as dataset:
            dataset.write(values, 1)


if __name__ == "__main__":
    unittest.main()
