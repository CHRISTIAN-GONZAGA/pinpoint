import 'package:pinpoint/core/config/app_config.dart';

/// Application-wide constants and configuration keys.
abstract final class AppConstants {
  static const String appName = 'PINPOINT';
  static const String appTagline = 'Navigate Smarter. Travel Better.';
  static const String appVersion = '2.0.0';

  /// When true, PINPOINT runs entirely from bundled assets and local storage.
  static const bool offlineFirstMode = AppConfig.offlineFirstMode;
  static const String cityName = 'Butuan City';

  static const String apiUrlKey = 'API_URL';
  static const String defaultApiUrl = AppConfig.apiUrl;

  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String themeModeKey = 'theme_mode';
  static const String languageKey = 'language_preference';

  static const String favoritesBoxName = 'favorites_box';
  static const String historyBoxName = 'history_box';
  static const String transportCacheBoxName = 'transport_cache_box';
  static const String routeCacheBoxName = 'route_cache_box';

  static const String largeTextKey = 'large_text_enabled';
  static const String reduceMotionKey = 'reduce_motion_enabled';
  static const String emergencyContactNameKey = 'emergency_contact_name';
  static const String emergencyContactPhoneKey = 'emergency_contact_phone';
  static const String biometricUnlockKey = 'biometric_unlock_enabled';
  static const String lastLoginEmailKey = 'last_login_email';
  static const String localProfileNameKey = 'local_profile_name';
  static const String localSeedCompleteKey = 'local_seed_complete';
  static const String placesCacheBoxName = 'places_cache_box';
  static const String knowledgeCacheBoxName = 'knowledge_cache_box';
  static const String announcementsCacheBoxName = 'announcements_cache_box';
  static const String developerModeKey = 'developer_mode_enabled';

  static const Duration splashDuration = Duration(milliseconds: 2500);
  static const Duration tokenRefreshBuffer = Duration(minutes: 5);

  // Butuan City center coordinates
  static const double butuanLat = 8.9475;
  static const double butuanLng = 125.5406;
  static const double defaultMapZoom = 14.0;

  // External services (development defaults)
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// Carto basemaps are reliable on mobile; OSM direct tiles often 403/block apps.
  static const List<String> mapTileSubdomains = ['a', 'b', 'c', 'd'];
  static const String lightTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
  static const String darkTileUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  static const String osmTileFallbackUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @Deprecated('Use lightTileUrl')
  static const String osmTileUrl = lightTileUrl;
}
