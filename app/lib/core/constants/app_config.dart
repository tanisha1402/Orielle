/// Build-time configuration.
///
/// Values are supplied with `--dart-define` so that no configuration or
/// secret is ever hard-coded in source control. Defaults give a fully offline
/// demo that uses the bundled SAMPLE dataset.
///
/// Example (use the future FastAPI backend from an Android emulator):
/// ```
/// flutter run --dart-define=ERC_USE_MOCK=false \
///             --dart-define=ERC_API_BASE_URL=http://10.0.2.2:8000
/// ```
class AppConfig {
  const AppConfig._();

  static const String appName = 'TerraLens';
  static const String tagline = 'From surface change to future risk';

  /// When true (default) the app uses [MockAnalysisRepository] and needs no
  /// backend. Set `ERC_USE_MOCK=false` to use the HTTP repository.
  static const bool useMockData =
      bool.fromEnvironment('ERC_USE_MOCK', defaultValue: true);

  /// Base URL of the FastAPI service, without a trailing slash and without
  /// `/api/v1` (for example `http://10.0.2.2:8000`).
  static const String apiBaseUrl =
      String.fromEnvironment('ERC_API_BASE_URL', defaultValue: '');

  /// Per-request timeout for the HTTP client.
  static const Duration apiTimeout = Duration(seconds: 15);

  /// Label used wherever demonstration records are shown.
  static const String sampleLabel = 'SAMPLE DATA';
}

/// Basemap configuration. Tile access needs no API key by default, but the
/// provider's usage policy and attribution rules MUST be respected.
///
/// The default is the public OpenStreetMap tile server, which is suitable for
/// development and low-traffic demos only
/// (https://operations.osmfoundation.org/policies/tiles/).
/// For production or heavy use, point `ERC_TILE_URL` at a provider whose
/// terms allow it and update `ERC_TILE_ATTRIBUTION` to match.
class MapConfig {
  const MapConfig._();

  static const String tileUrlTemplate = String.fromEnvironment(
    'ERC_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// Attribution text shown on the map (the map widget prepends the
  /// copyright sign). Required by most tile providers.
  static const String tileAttribution = String.fromEnvironment(
    'ERC_TILE_ATTRIBUTION',
    defaultValue: 'OpenStreetMap contributors',
  );

  /// Identifies this app to the tile server (required by the OSM policy).
  static const String userAgentPackageName = String.fromEnvironment(
    'ERC_TILE_USER_AGENT',
    defaultValue: 'org.earthriskchain.frontend',
  );

  static const int tileMaxNativeZoom = 19;
  static const double minZoom = 3;
  static const double maxZoom = 18;

  /// Number of failed tile requests after which the UI offers the offline
  /// schematic basemap.
  static const int tileErrorThreshold = 8;
}
