export interface RasterTileJsonSources {
  before: string | null;
  after: string | null;
  newWater: string | null;
}

export type ApiDataStatus = "checking" | "waiting" | "ready" | "unavailable";

const optionalUrl = (value: string | undefined): string | null => {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
};

const apiBaseUrl =
  optionalUrl(import.meta.env.VITE_TERRALENS_API_URL) ??
  "http://127.0.0.1:8000";

export const LOCAL_INTEGRATION = {
  statusUrl:
    optionalUrl(import.meta.env.VITE_TERRALENS_STATUS_URL) ??
    `${apiBaseUrl}/api/status`,
  sceneMetadataUrl:
    optionalUrl(import.meta.env.VITE_SAR_METADATA_URL) ??
    `${apiBaseUrl}/api/results`,
  changeResultUrl:
    optionalUrl(import.meta.env.VITE_CHANGE_RESULT_URL) ??
    `${apiBaseUrl}/api/results`,
  rasterTileJson: {
    before:
      optionalUrl(import.meta.env.VITE_BEFORE_TILEJSON_URL) ??
      `${apiBaseUrl}/tiles/before_water/tiles.json`,
    after:
      optionalUrl(import.meta.env.VITE_AFTER_TILEJSON_URL) ??
      `${apiBaseUrl}/tiles/after_water/tiles.json`,
    newWater:
      optionalUrl(import.meta.env.VITE_NEW_WATER_TILEJSON_URL) ??
      `${apiBaseUrl}/tiles/new_water/tiles.json`,
  } satisfies RasterTileJsonSources,
};

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function parseApiDataStatus(payload: unknown): ApiDataStatus {
  if (!isRecord(payload) || typeof payload.status !== "string") {
    throw new Error("Local API returned an invalid status response.");
  }
  if (payload.status === "ready") {
    return "ready";
  }
  if (payload.status === "waiting_for_sar_processing") {
    return "waiting";
  }
  throw new Error(`Local API returned an unsupported status: ${payload.status}`);
}
