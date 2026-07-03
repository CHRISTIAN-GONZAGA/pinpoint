import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';

/// Pull/push synchronization for registered users.
class SyncRemoteDataSource {
  SyncRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<Map<String, dynamic>> pull() async {
    final response = await _api.get<Map<String, dynamic>>('/sync/pull');
    return response.data ?? {};
  }

  Future<void> pushPreferences({
    required String languagePreference,
    required String themePreference,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/sync/preferences',
      data: {
        'language_preference': languagePreference,
        'theme_preference': themePreference,
      },
    );
  }

  Future<void> mergeFavorites(List<Map<String, dynamic>> favorites) async {
    await _api.post<Map<String, dynamic>>(
      '/sync/favorites',
      data: {'favorites': favorites},
    );
  }
}
