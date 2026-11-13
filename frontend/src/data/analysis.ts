export interface ChangeSummary {
  newWaterAreaKm2: number;
  thresholdDb: number;
  pixelAreaM2: number;
  minComponentPixels: number;
  pixelSpacingMeters: { x: number; y: number };
  commonValidPixels: number;
  comparisonGridPixels: number;
  crs: string;
}

export function parseChangeSummary(payload: unknown): ChangeSummary {
  if (!isRecord(payload)) {
    throw new Error("Change summary response must be a JSON object.");
  }

  const area = payload.new_water_area_km2;
  const threshold = payload.threshold_db;
  const pixelArea = payload.pixel_area_m2;
  const minimum = payload.min_component_pixels;
  const spacing = payload.pixel_spacing_m;
  const comparison = payload.comparison;
  const commonValidPixels =
    isRecord(comparison) ? comparison.common_valid_pixels : null;
  const width = payload.width;
  const height = payload.height;
  const crs = payload.crs;
  if (
    typeof area !== "number" ||
    !Number.isFinite(area) ||
    area < 0 ||
    typeof threshold !== "number" ||
    !Number.isFinite(threshold) ||
    typeof pixelArea !== "number" ||
    !Number.isFinite(pixelArea) ||
    pixelArea <= 0 ||
    typeof minimum !== "number" ||
    !Number.isInteger(minimum) ||
    minimum < 1 ||
    !isRecord(spacing) ||
    typeof spacing.x !== "number" ||
    !Number.isFinite(spacing.x) ||
    spacing.x <= 0 ||
    typeof spacing.y !== "number" ||
    !Number.isFinite(spacing.y) ||
    spacing.y <= 0 ||
    typeof commonValidPixels !== "number" ||
    !Number.isInteger(commonValidPixels) ||
    commonValidPixels < 0 ||
    typeof width !== "number" ||
    !Number.isInteger(width) ||
    width < 1 ||
    typeof height !== "number" ||
    !Number.isInteger(height) ||
    height < 1 ||
    commonValidPixels > width * height ||
    typeof crs !== "string" ||
    crs.trim().length === 0
  ) {
    throw new Error("Change summary contains invalid measurements.");
  }

  return {
    newWaterAreaKm2: area,
    thresholdDb: threshold,
    pixelAreaM2: pixelArea,
    minComponentPixels: minimum,
    pixelSpacingMeters: { x: spacing.x, y: spacing.y },
    commonValidPixels,
    comparisonGridPixels: width * height,
    crs,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
