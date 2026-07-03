import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';

/// Remote user profile and settings API.
class UserSettingsRemoteDataSource {
  UserSettingsRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) async {
    final response = await _api.patch<Map<String, dynamic>>('/users/profile', data: payload);
    return response.data ?? {};
  }

  Future<void> registerDevice({required String token, String platform = 'android'}) async {
    await _api.post<Map<String, dynamic>>(
      '/users/devices',
      data: {'token': token, 'platform': platform},
    );
  }
}
