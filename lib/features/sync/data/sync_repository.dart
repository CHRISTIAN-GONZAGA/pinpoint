import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/favorites/data/favorites_local_datasource.dart';
import 'package:pinpoint/features/sync/data/sync_remote_datasource.dart';

/// Coordinates cloud sync for profile, favorites, and preferences.
class SyncRepository {
  SyncRepository({
    required SyncRemoteDataSource remote,
    required ApiClient apiClient,
    required FavoritesLocalDataSource favoritesLocal,
  })  : _remote = remote,
        _apiClient = apiClient,
        _favoritesLocal = favoritesLocal;

  final SyncRemoteDataSource _remote;
  final ApiClient _apiClient;
  final FavoritesLocalDataSource _favoritesLocal;

  Future<void> syncForUser({
    required ThemeMode themeMode,
    required String languagePreference,
  }) async {
    try {
      final localFavorites = await _favoritesLocal.getAll();
      if (localFavorites.isNotEmpty) {
        await _remote.mergeFavorites(localFavorites);
      }
      await _remote.pushPreferences(
        languagePreference: languagePreference,
        themePreference: _themeValue(themeMode),
      );
      await _remote.pull();
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }

  String _themeValue(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
