/// Build-time configuration via `--dart-define` or `--dart-define-from-file`.
///
/// Example:
/// ```bash
/// flutter run --dart-define-from-file=.env.flutter.json
/// ```
abstract final class AppConfig {
  /// PINPOINT REST API base URL (must include `/api` suffix).
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://pinpoint-api.onrender.com/api',
  );

  /// When true, the app skips the cloud API and uses bundled local data only.
  static const bool offlineFirstMode = bool.fromEnvironment(
    'OFFLINE_FIRST_MODE',
    defaultValue: false,
  );

  /// Map tile provider: `carto` (free), `maptiler`, or `mapbox`.
  static const String mapTileProvider = String.fromEnvironment(
    'MAP_TILE_PROVIDER',
    defaultValue: 'carto',
  );

  /// API key for MapTiler or Mapbox raster tiles (optional).
  static const String mapTileApiKey = String.fromEnvironment(
    'MAP_TILE_API_KEY',
    defaultValue: '',
  );

  static bool get usesRenderCloud =>
      apiUrl.contains('onrender.com') || apiUrl.startsWith('https://');
}
