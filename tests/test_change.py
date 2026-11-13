import tempfile
import unittest
from pathlib import Path

import numpy as np
import rasterio
from affine import Affine
from rasterio.transform import from_origin

from src.compute.change import (
    calculate_area_km2,
    detect_water_change,
    detect_water_change_geospatial,
    power_to_db,
    remove_small_components,
)


class ChangeDetectionTests(unittest.TestCase):
    def test_removes_components_smaller_than_minimum(self):
        water = np.array(
            [
                [1, 1, 0, 0, 1],
                [1, 0, 0, 0, 0],
                [0, 0, 1, 0, 0],
            ],
            dtype=bool,
        )

        filtered = remove_small_components(water, min_component_pixels=2)

        expected = np.zeros_like(water)
        expected[0, 0] = True
        expected[0, 1] = True
        expected[1, 0] = True
        np.testing.assert_array_equal(filtered, expected)

    def test_eight_connected_diagonal_component_is_retained(self):
        diagonal_component = np.array(
            [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
            dtype=bool,
        )

        filtered = remove_small_components(
            diagonal_component,
            min_component_pixels=3,
        )

        np.testing.assert_array_equal(filtered, diagonal_component)

    def test_before_after_and_new_water_masks(self):
        before = np.array(
            [
                [0.01, 0.1, 0.1],
                [0.1, 0.01, 0.1],
                [0.1, 0.1, 0.1],
            ],
            dtype=np.float32,
        )
        after = np.array(
            [
                [0.01, 0.01, 0.1],
                [0.1, 0.01, 0.01],
                [0.1, 0.1, 0.1],
            ],
            dtype=np.float32,
        )

        with tempfile.TemporaryDirectory() as temporary:
            before_path = self._write_raster(Path(temporary) / "before.tif", before)
            after_path = self._write_raster(Path(temporary) / "after.tif", after)
            result = detect_water_change(
                before_path,
                after_path,
                threshold_db=-15,
                min_component_pixels=1,
            )

        np.testing.assert_array_equal(
            result.before_water,
            np.array(
                [
                    [1, 0, 0],
                    [0, 1, 0],
                    [0, 0, 0],
                ],
                dtype=bool,
            ),
        )
        np.testing.assert_array_equal(
            result.after_water,
            np.array(
                [
                    [1, 1, 0],
                    [0, 1, 1],
                    [0, 0, 0],
                ],
                dtype=bool,
            ),
        )
        np.testing.assert_array_equal(
            result.new_water,
            np.array(
                [
                    [0, 1, 0],
                    [0, 0, 1],
                    [0, 0, 0],
                ],
                dtype=bool,
            ),
        )

    def test_known_area_from_ten_metre_pixels(self):
        ten_pixels = np.ones((2, 5), dtype=bool)
        transform = Affine(10, 0, 500000, 0, -10, 2700000)

        area = calculate_area_km2(ten_pixels, transform, "EPSG:32646")

        self.assertAlmostEqual(area, 0.001)

    def test_area_uses_each_pixel_resolution(self):
        ten_pixels = np.ones((2, 5), dtype=bool)

        for spacing, expected_km2 in (
            (5, 0.00025),
            (10, 0.001),
            (20, 0.004),
        ):
            with self.subTest(spacing_m=spacing):
                transform = Affine(
                    spacing,
                    0,
                    500000,
                    0,
                    -spacing,
                    2700000,
                )
                area = calculate_area_km2(
                    ten_pixels,
                    transform,
                    "EPSG:32646",
                )
                self.assertAlmostEqual(area, expected_km2)

    def test_area_uses_affine_determinant_for_rectangular_pixels(self):
        ten_pixels = np.ones((2, 5), dtype=bool)
        transform = Affine(20, 0, 500000, 0, -5, 2700000)

        area = calculate_area_km2(ten_pixels, transform, "EPSG:32646")

        self.assertAlmostEqual(area, 0.001)

    def test_nodata_zero_negative_nan_and_infinity_are_excluded(self):
        invalid_and_valid = np.array(
            [[-9999, 0, -0.5], [np.nan, np.inf, 0.01]], dtype=np.float32
        )
        after = np.full((2, 3), 0.01, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            before_path = self._write_raster(
                Path(temporary) / "before.tif",
                invalid_and_valid,
                nodata=-9999,
            )
            after_path = self._write_raster(Path(temporary) / "after.tif", after)
            result = detect_water_change(
                before_path, after_path, min_component_pixels=1
            )

        expected_valid = np.array(
            [[False, False, False], [False, False, True]], dtype=bool
        )
        np.testing.assert_array_equal(result.before_valid, expected_valid)
        self.assertTrue(np.isnan(result.before_db[0, 0]))
        self.assertTrue(np.isnan(result.before_db[0, 1]))
        self.assertTrue(np.isnan(result.before_db[0, 2]))
        self.assertTrue(np.isnan(result.before_db[1, 0]))
        self.assertTrue(np.isnan(result.before_db[1, 1]))
        self.assertFalse(result.new_water.any())

    def test_rejects_mismatched_pixel_grid(self):
        raster = np.full((2, 2), 0.01, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(root / "before.tif", raster)
            after_path = self._write_raster(
                root / "after.tif",
                raster,
                transform=from_origin(500010, 2700000, 10, 10),
            )

            with self.assertRaisesRegex(ValueError, "transforms differ"):
                detect_water_change(before_path, after_path)

    def test_rejects_different_crs_and_dimensions(self):
        raster = np.full((2, 2), 0.1, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(root / "before.tif", raster)

            other_crs_path = self._write_raster(
                root / "other_crs.tif",
                raster,
                crs="EPSG:32645",
            )
            with self.assertRaisesRegex(ValueError, "CRS differ"):
                detect_water_change(before_path, other_crs_path)

            other_dimensions_path = self._write_raster(
                root / "other_dimensions.tif",
                np.full((2, 3), 0.1, dtype=np.float32),
            )
            with self.assertRaisesRegex(ValueError, "dimensions differ"):
                detect_water_change(before_path, other_dimensions_path)

    def test_strict_detector_rejects_different_resolution(self):
        raster = np.full((2, 2), 0.1, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(root / "before.tif", raster)
            other_resolution_path = self._write_raster(
                root / "other_resolution.tif",
                raster,
                transform=from_origin(500000, 2700000, 20, 20),
            )
            with self.assertRaisesRegex(ValueError, "transforms differ"):
                detect_water_change(before_path, other_resolution_path)

    def test_geospatial_alignment_reprojects_different_crs(self):
        from rasterio.warp import transform as transform_coordinates

        longitude, latitude = 89.8, 24.5
        before_x, before_y = transform_coordinates(
            "EPSG:4326",
            "EPSG:32646",
            [longitude],
            [latitude],
        )
        after_x, after_y = transform_coordinates(
            "EPSG:4326",
            "EPSG:32645",
            [longitude],
            [latitude],
        )
        before_transform = from_origin(
            before_x[0] - 5,
            before_y[0] + 5,
            10,
            10,
        )
        after_transform = from_origin(
            after_x[0] - 5,
            after_y[0] + 5,
            10,
            10,
        )
        before = np.full((10, 10), 0.1, dtype=np.float32)
        after = np.full((10, 10), 0.01, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(
                root / "before.tif",
                before,
                crs="EPSG:32646",
                transform=before_transform,
            )
            after_path = self._write_raster(
                root / "after.tif",
                after,
                crs="EPSG:32645",
                transform=after_transform,
            )
            result = detect_water_change_geospatial(before_path, after_path)

        self.assertEqual(result.crs.to_string(), "EPSG:32646")
        self.assertGreater(np.count_nonzero(result.after_valid), 0)
        np.testing.assert_array_equal(result.before_valid, result.after_valid)
        self.assertTrue(result.new_water.any())

    def test_geospatial_alignment_resamples_different_resolution(self):
        before = np.full((4, 4), 0.1, dtype=np.float32)
        after = np.full((2, 2), 0.01, dtype=np.float32)
        before_transform = from_origin(500000, 2700040, 10, 10)
        after_transform = from_origin(500000, 2700040, 20, 20)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(
                root / "before.tif",
                before,
                transform=before_transform,
            )
            after_path = self._write_raster(
                root / "after.tif",
                after,
                transform=after_transform,
            )
            result = detect_water_change_geospatial(before_path, after_path)

        self.assertEqual(result.before_water.shape, (4, 4))
        self.assertTrue(result.before_valid.all())
        self.assertTrue(result.after_valid.all())
        self.assertTrue(result.new_water.all())
        self.assertAlmostEqual(result.new_water_area_km2, 0.0016)

    def test_geospatial_alignment_crops_partial_overlap_and_masks_invalid_pixels(self):
        before = np.full((4, 4), 0.1, dtype=np.float32)
        after = np.full((3, 3), 0.01, dtype=np.float32)
        after[1, 1] = 0.0
        before_transform = from_origin(500000, 2700040, 10, 10)
        after_transform = from_origin(500010, 2700030, 10, 10)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(
                root / "before.tif",
                before,
                transform=before_transform,
            )
            after_path = self._write_raster(
                root / "after.tif",
                after,
                transform=after_transform,
                nodata=0,
            )
            result = detect_water_change_geospatial(before_path, after_path)

        self.assertEqual(result.before_water.shape, (3, 3))
        self.assertEqual(
            result.transform,
            from_origin(500010, 2700030, 10, 10),
        )
        self.assertEqual(np.count_nonzero(result.before_valid), 8)
        np.testing.assert_array_equal(result.before_valid, result.after_valid)
        self.assertFalse(result.new_water[1, 1])
        self.assertEqual(np.count_nonzero(result.new_water), 8)
        self.assertAlmostEqual(result.new_water_area_km2, 0.0008)

    def test_geospatial_alignment_rejects_non_overlapping_rasters(self):
        raster = np.full((2, 2), 0.01, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(
                root / "before.tif",
                raster,
                transform=from_origin(500000, 2700000, 10, 10),
            )
            after_path = self._write_raster(
                root / "after.tif",
                raster,
                transform=from_origin(600000, 2700000, 10, 10),
            )
            with self.assertRaisesRegex(ValueError, "no geographic"):
                detect_water_change_geospatial(before_path, after_path)

    def test_empty_water_masks_have_zero_area(self):
        dry = np.full((2, 3), 0.1, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(root / "before.tif", dry)
            after_path = self._write_raster(root / "after.tif", dry)
            result = detect_water_change(before_path, after_path)

        self.assertFalse(result.before_water.any())
        self.assertFalse(result.after_water.any())
        self.assertFalse(result.new_water.any())
        self.assertEqual(result.new_water_area_km2, 0.0)

    def test_all_water_after_scene_has_known_new_water_area(self):
        dry = np.full((2, 3), 0.1, dtype=np.float32)
        water = np.full((2, 3), 0.01, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(root / "before.tif", dry)
            after_path = self._write_raster(root / "after.tif", water)
            result = detect_water_change(before_path, after_path)

        self.assertFalse(result.before_water.any())
        self.assertTrue(result.after_water.all())
        self.assertTrue(result.new_water.all())
        self.assertAlmostEqual(result.new_water_area_km2, 0.0006)

    def test_identical_all_water_scenes_have_no_new_water(self):
        water = np.full((2, 3), 0.01, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(root / "before.tif", water)
            after_path = self._write_raster(root / "after.tif", water)
            result = detect_water_change(before_path, after_path)

        self.assertTrue(result.before_water.all())
        self.assertTrue(result.after_water.all())
        self.assertFalse(result.new_water.any())
        self.assertEqual(result.new_water_area_km2, 0.0)

    def test_threshold_is_configurable(self):
        dry = np.full((1, 1), 0.1, dtype=np.float32)
        borderline = np.full((1, 1), 0.02, dtype=np.float32)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            before_path = self._write_raster(root / "before.tif", dry)
            after_path = self._write_raster(root / "after.tif", borderline)
            permissive = detect_water_change(
                before_path,
                after_path,
                threshold_db=-15,
            )
            conservative = detect_water_change(
                before_path,
                after_path,
                threshold_db=-18,
            )

        self.assertTrue(permissive.new_water[0, 0])
        self.assertFalse(conservative.new_water[0, 0])

    def test_power_to_db_uses_ten_log_ten_and_marks_invalid_nan(self):
        power = np.array([[1.0, 0.1, 0.01, 0.0, -1.0, np.nan, np.inf]])

        result = power_to_db(power)

        np.testing.assert_allclose(result[0, :3], [0.0, -10.0, -20.0])
        self.assertTrue(np.isnan(result[0, 3:]).all())

    def test_area_rejects_geographic_and_non_metric_crs(self):
        mask = np.ones((1, 1), dtype=bool)
        transform = Affine(10, 0, 0, 0, -10, 0)
        with self.assertRaisesRegex(ValueError, "projected CRS"):
            calculate_area_km2(mask, transform, "EPSG:4326")
        with self.assertRaisesRegex(ValueError, "metric pixel units"):
            calculate_area_km2(mask, transform, "EPSG:2263")

    @staticmethod
    def _write_raster(
        path: Path,
        values: np.ndarray,
        *,
        transform: Affine | None = None,
        crs: str = "EPSG:32646",
        nodata: float = -9999,
    ) -> Path:
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
            crs=crs,
            transform=transform,
            nodata=nodata,
        ) as dataset:
            dataset.write(values, 1)
        return path


if __name__ == "__main__":
    unittest.main()
