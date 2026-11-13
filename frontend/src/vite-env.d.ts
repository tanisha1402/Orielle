/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_TERRALENS_API_URL?: string;
  readonly VITE_TERRALENS_STATUS_URL?: string;
  readonly VITE_SAR_METADATA_URL?: string;
  readonly VITE_CHANGE_RESULT_URL?: string;
  readonly VITE_BEFORE_TILEJSON_URL?: string;
  readonly VITE_AFTER_TILEJSON_URL?: string;
  readonly VITE_NEW_WATER_TILEJSON_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
