import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy
import rasterio
from rasterio.transform import from_origin

from scripts.data import prepare_sar


AFTER_SCENE = (
    "S1A_IW_GRDH_1SDV_20210214T154837_20210214T154901_036588_044C54_032E"
)


class PrepareSarTests(unittest.TestCase):
    def test_job_definitions_use_verified_rtc_options(self):
        scenes = [
            prepare_sar.parse_scene_id(prepare_sar.BEFORE_SCENE_ID, "before"),
            prepare_sar.parse_scene_id(AFTER_SCENE, "after"),
        ]

        jobs = prepare_sar.make_job_definitions(scenes)

        self.assertEqual(len(jobs), 2)
        for job, scene in zip(jobs, scenes):
            self.assertEqual(job["job_type"], "RTC_GAMMA")
            self.assertEqual(job["job_parameters"]["granules"], [scene.scene_id])
            self.assertEqual(job["job_parameters"]["radiometry"], "sigma0")
            self.assertEqual(job["job_parameters"]["scale"], "power")
            self.assertEqual(job["job_parameters"]["resolution"], 10)
            self.assertEqual(job["job_parameters"]["dem_name"], "copernicus")

    def test_dry_run_does_not_initialize_hyp3_authentication(self):
        output = io.StringIO()
        with patch.object(
            prepare_sar.HyP3,
            "__init__",
            side_effect=AssertionError("dry-run must not authenticate"),
        ):
            with contextlib.redirect_stdout(output):
                result = prepare_sar.main(
                    ["--after-scene", AFTER_SCENE, "--dry-run"]
                )

        self.assertEqual(result, 0)
        self.assertIn("no credentials requested and no network calls made", output.getvalue())

    def test_rejects_non_later_after_scene(self):
        error_output = io.StringIO()
        with self.assertRaises(SystemExit) as error:
            with contextlib.redirect_stderr(error_output):
                prepare_sar.main(
                    ["--after-scene", prepare_sar.BEFORE_SCENE_ID, "--dry-run"]
                )
        self.assertEqual(error.exception.code, 2)

    def test_live_execution_requires_explicit_submission_confirmation(self):
        error_output = io.StringIO()
        with self.assertRaises(SystemExit) as error:
            with contextlib.redirect_stderr(error_output):
                prepare_sar.main(["--after-scene", AFTER_SCENE])

        self.assertEqual(error.exception.code, 2)
        self.assertIn("--confirm-submit", error_output.getvalue())

    def test_describes_cross_scene_reprojection_and_rejects_misaligned_polarizations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_vv = self._write_raster(root / "before_VV.tif", 500000)
            before_vh = self._write_raster(root / "before_VH.tif", 500000)
            after_vv = self._write_raster(root / "after_VV.tif", 500010)
            after_vh = self._write_raster(root / "after_VH.tif", 500010)
            before = {
                "VV": prepare_sar._read_raster(before_vv),
                "VH": prepare_sar._read_raster(before_vh),
            }
            after = {
                "VV": prepare_sar._read_raster(after_vv),
                "VH": prepare_sar._read_raster(after_vh),
            }

            result = prepare_sar.describe_pair_alignment(before, after)
            self.assertFalse(result["VV"]["native_grids_match"])
            self.assertTrue(result["VV"]["reprojection_required"])
            self.assertEqual(result["VV"]["reference_grid"], "before")

            after["VH"] = prepare_sar._read_raster(
                self._write_raster(root / "misaligned_after_VH.tif", 500020)
            )
            with self.assertRaisesRegex(ValueError, "VV and VH"):
                prepare_sar.describe_pair_alignment(before, after)

    def test_converts_non_cog_geotiff_to_cog(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = self._write_raster(root / "source_VV.tif", 500000)
            destination = prepare_sar._make_cog(source, root / "cog" / source.name)

            self.assertTrue(prepare_sar._is_cog(destination))
            self.assertEqual(prepare_sar._read_raster(destination)["resolution_m"], [10.0, 10.0])

    def test_rejects_geographic_crs_as_ten_metre_grid(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = self._write_raster(
                Path(temporary) / "degrees_VV.tif",
                500000,
                crs="EPSG:4326",
            )
            with self.assertRaisesRegex(ValueError, "projected CRS with metre units"):
                prepare_sar._read_raster(path)

    @staticmethod
    def _write_raster(
        path: Path, x_origin: float, crs: str = "EPSG:32646"
    ) -> Path:
        with rasterio.open(
            path,
            "w",
            driver="GTiff",
            width=3,
            height=2,
            count=1,
            dtype="uint8",
            crs=crs,
            transform=from_origin(x_origin, 2700000, 10, 10),
            nodata=0,
        ) as dataset:
            dataset.write(numpy.zeros((2, 3), dtype="uint8"), 1)
        return path


if __name__ == "__main__":
    unittest.main()
