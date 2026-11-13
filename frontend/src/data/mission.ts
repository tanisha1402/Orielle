export interface SceneObservation {
  sceneId: string | null;
  acquiredAtUtc: string | null;
}

export interface ScenePairMetadata {
  before: SceneObservation;
  after: SceneObservation;
}

export const JAMUNA_STUDY_AREA = {
  name: "Jamuna River",
  subregion: "Near Sirajganj, Bangladesh",
  center: [89.72, 24.45] as [number, number],
  zoom: 9.2,
};

export const INITIAL_SCENE_PAIR: ScenePairMetadata = {
  before: {
    sceneId:
      "S1A_IW_GRDH_1SDV_20200713T120451_20200713T120516_033436_03DFD8_67E8",
    acquiredAtUtc: "2020-07-13T12:04:51Z",
  },
  after: {
    sceneId: null,
    acquiredAtUtc: null,
  },
};

export const PROCESSING_DEFAULTS = {
  thresholdDb: -15,
  minComponentPixels: 1,
  steps: [
    "Read calibrated Sentinel-1 VV RTC Sigma0 power rasters.",
    "Convert positive, valid power values to dB with 10 × log10(power).",
    "Exclude nodata, zero, negative, NaN, and infinite pixels.",
    "Classify water at or below the configurable dB threshold.",
    "Filter connected components below the configured pixel minimum.",
    "Compare only aligned pixels valid in both dates.",
    "Calculate observed new-water area from the affine pixel dimensions.",
  ],
  uncertainty:
    "Low backscatter is not proof of flooding. Vegetation, urban double-bounce, soil moisture, acquisition geometry, and threshold choice can change the result. Observed change may be flood-related, but a 17-day interval cannot establish when or why it happened. Confirmed flood extent is not claimed.",
};

export function parseScenePairMetadata(payload: unknown): ScenePairMetadata {
  if (!isRecord(payload) || !Array.isArray(payload.scenes)) {
    throw new Error("Scene metadata response must contain a scenes array.");
  }

  const before = parseScene(payload.scenes, "before");
  const after = parseScene(payload.scenes, "after");
  if (before.sceneId === null) {
    throw new Error("Scene metadata response does not include the before scene.");
  }

  return { before, after };
}

function parseScene(
  scenes: unknown[],
  role: "before" | "after",
): SceneObservation {
  const scene = scenes.find(
    (candidate) => isRecord(candidate) && candidate.role === role,
  );
  if (!isRecord(scene)) {
    return { sceneId: null, acquiredAtUtc: null };
  }

  return {
    sceneId: typeof scene.scene_id === "string" ? scene.scene_id : null,
    acquiredAtUtc:
      typeof scene.acquisition_start_utc === "string"
        ? scene.acquisition_start_utc
        : null,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
