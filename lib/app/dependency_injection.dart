import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/local/local_profile_service.dart';
import 'package:pinpoint/core/local/local_seed_service.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/core/theme/app_theme.dart';
import 'package:pinpoint/features/ai_chat/data/ai_local_datasource.dart';
import 'package:pinpoint/features/ai_chat/data/ai_remote_datasource.dart';
import 'package:pinpoint/features/ai_chat/data/ai_repository.dart';
import 'package:pinpoint/features/ai_chat/data/ai_history_remote_datasource.dart';
import 'package:pinpoint/features/ai_chat/data/ai_history_repository.dart';
import 'package:pinpoint/features/authentication/data/auth_local_datasource.dart';
import 'package:pinpoint/features/authentication/data/auth_remote_datasource.dart';
import 'package:pinpoint/features/authentication/data/auth_repository_impl.dart';
import 'package:pinpoint/core/services/geocoding_service.dart';
import 'package:pinpoint/core/services/location_service.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/core/services/route_cache_service.dart';
import 'package:pinpoint/core/services/biometric_service.dart';
import 'package:pinpoint/features/map/data/transport_asset_datasource.dart';
import 'package:pinpoint/features/map/data/transport_local_datasource.dart';
import 'package:pinpoint/features/map/data/transport_remote_datasource.dart';
import 'package:pinpoint/features/map/data/transport_repository.dart';
import 'package:pinpoint/features/routing/domain/route_planner_service.dart';
import 'package:pinpoint/features/explore/data/places_asset_datasource.dart';
import 'package:pinpoint/features/explore/data/places_local_datasource.dart';
import 'package:pinpoint/features/explore/data/places_remote_datasource.dart';
import 'package:pinpoint/features/explore/data/places_repository.dart';
import 'package:pinpoint/features/favorites/data/favorites_local_datasource.dart';
import 'package:pinpoint/features/favorites/data/favorites_repository.dart';
import 'package:pinpoint/features/history/data/history_local_datasource.dart';
import 'package:pinpoint/features/history/data/history_repository.dart';
import 'package:pinpoint/features/admin/data/admin_remote_datasource.dart';
import 'package:pinpoint/features/admin/data/admin_repository.dart';
import 'package:pinpoint/features/notifications/data/notifications_local_datasource.dart';
import 'package:pinpoint/features/notifications/data/notifications_remote_datasource.dart';
import 'package:pinpoint/features/notifications/data/notifications_repository.dart';
import 'package:pinpoint/features/reports/data/reports_remote_datasource.dart';
import 'package:pinpoint/features/reports/data/reports_repository.dart';
import 'package:pinpoint/features/sync/data/sync_remote_datasource.dart';
import 'package:pinpoint/features/sync/data/sync_repository.dart';
import 'package:pinpoint/features/profile/data/user_settings_remote_datasource.dart';
import 'package:pinpoint/features/profile/data/user_settings_repository.dart';

/// Global Riverpod providers for core services and repositories.
final localProfileServiceProvider = Provider<LocalProfileService>((ref) {
  return LocalProfileService();
});

final localSeedServiceProvider = Provider<LocalSeedService>((ref) {
  return LocalSeedService(
    transportLocal: ref.watch(transportLocalDataSourceProvider),
  );
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSource();
});

final apiClientProviderOverride = Provider<ApiClient>((ref) {
  final authLocal = ref.watch(authLocalDataSourceProvider);
  return ApiClient(
    baseUrl: AppConstants.defaultApiUrl,
    authLocal: authLocal,
  );
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    apiClient: ref.watch(apiClientProviderOverride),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    localProfileService: ref.watch(localProfileServiceProvider),
  );
});

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final geocodingServiceProvider =
    Provider<GeocodingService>((ref) => GeocodingService());

final routingServiceProvider =
    Provider<RoutingService>((ref) => RoutingService());

final jeepneyPathServiceProvider =
    Provider<JeepneyPathService>((ref) => JeepneyPathService(
          routingService: ref.watch(routingServiceProvider),
        ));

final routePlannerServiceProvider =
    Provider<RoutePlannerService>((ref) => RoutePlannerService(
          routingService: ref.watch(routingServiceProvider),
          jeepneyPaths: ref.watch(jeepneyPathServiceProvider),
        ));

final transportRemoteDataSourceProvider = Provider<TransportRemoteDataSource>((ref) {
  return TransportRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final transportLocalDataSourceProvider = Provider<TransportLocalDataSource>((ref) {
  return TransportLocalDataSource();
});

final transportAssetDataSourceProvider = Provider<TransportAssetDataSource>((ref) {
  return TransportAssetDataSource(local: ref.watch(transportLocalDataSourceProvider));
});

final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  return TransportRepository(
    remoteDataSource: ref.watch(transportRemoteDataSourceProvider),
    localDataSource: ref.watch(transportLocalDataSourceProvider),
    assetDataSource: ref.watch(transportAssetDataSourceProvider),
  );
});

final routeCacheServiceProvider = Provider<RouteCacheService>((ref) => RouteCacheService());

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

final placesRemoteDataSourceProvider = Provider<PlacesRemoteDataSource>((ref) {
  return PlacesRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final placesLocalDataSourceProvider = Provider<PlacesLocalDataSource>((ref) {
  return PlacesLocalDataSource();
});

final placesAssetDataSourceProvider = Provider<PlacesAssetDataSource>((ref) {
  return PlacesAssetDataSource();
});

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository(
    remote: ref.watch(placesRemoteDataSourceProvider),
    local: ref.watch(placesLocalDataSourceProvider),
    assets: ref.watch(placesAssetDataSourceProvider),
  );
});

final favoritesLocalDataSourceProvider = Provider<FavoritesLocalDataSource>((ref) {
  return FavoritesLocalDataSource();
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(
    remote: ref.watch(placesRemoteDataSourceProvider),
    local: ref.watch(favoritesLocalDataSourceProvider),
  );
});

final historyLocalDataSourceProvider = Provider<HistoryLocalDataSource>((ref) {
  return HistoryLocalDataSource();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(
    remote: ref.watch(placesRemoteDataSourceProvider),
    local: ref.watch(historyLocalDataSourceProvider),
  );
});

final aiRemoteDataSourceProvider = Provider<AiRemoteDataSource>((ref) {
  return AiRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final aiLocalDataSourceProvider = Provider<AiLocalDataSource>((ref) {
  return AiLocalDataSource();
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(
    remote: ref.watch(aiRemoteDataSourceProvider),
    local: ref.watch(aiLocalDataSourceProvider),
    apiClient: ref.watch(apiClientProviderOverride),
  );
});

final aiHistoryRemoteDataSourceProvider = Provider<AiHistoryRemoteDataSource>((ref) {
  return AiHistoryRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final aiHistoryRepositoryProvider = Provider<AiHistoryRepository>((ref) {
  return AiHistoryRepository(
    remote: ref.watch(aiHistoryRemoteDataSourceProvider),
    apiClient: ref.watch(apiClientProviderOverride),
  );
});

final userSettingsRemoteDataSourceProvider = Provider<UserSettingsRemoteDataSource>((ref) {
  return UserSettingsRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(
    remote: ref.watch(userSettingsRemoteDataSourceProvider),
    apiClient: ref.watch(apiClientProviderOverride),
  );
});

final notificationsRemoteDataSourceProvider = Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final notificationsLocalDataSourceProvider = Provider<NotificationsLocalDataSource>((ref) {
  return NotificationsLocalDataSource();
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(
    remote: ref.watch(notificationsRemoteDataSourceProvider),
    local: ref.watch(notificationsLocalDataSourceProvider),
    apiClient: ref.watch(apiClientProviderOverride),
  );
});

final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>((ref) {
  return AdminRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(
    remote: ref.watch(adminRemoteDataSourceProvider),
    apiClient: ref.watch(apiClientProviderOverride),
  );
});

final reportsRemoteDataSourceProvider = Provider<ReportsRemoteDataSource>((ref) {
  return ReportsRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(
    remote: ref.watch(reportsRemoteDataSourceProvider),
    apiClient: ref.watch(apiClientProviderOverride),
  );
});

final syncRemoteDataSourceProvider = Provider<SyncRemoteDataSource>((ref) {
  return SyncRemoteDataSource(apiClient: ref.watch(apiClientProviderOverride));
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(
    remote: ref.watch(syncRemoteDataSourceProvider),
    apiClient: ref.watch(apiClientProviderOverride),
    favoritesLocal: ref.watch(favoritesLocalDataSourceProvider),
  );
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Persists and exposes the application theme mode preference.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> load() async {
    final stored = await ref.read(authLocalDataSourceProvider).getThemeMode();
    state = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ref.read(authLocalDataSourceProvider).setThemeMode(value);
  }
}

/// Root widget overrides for dependency injection.
class AppProviderScope extends ConsumerWidget {
  const AppProviderScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWith((ref) => ref.watch(apiClientProviderOverride)),
      ],
      child: child,
    );
  }
}

/// Convenience accessor for light/dark themes.
abstract final class PinpointThemes {
  static ThemeData get light => AppTheme.light();
  static ThemeData get dark => AppTheme.dark();
}
