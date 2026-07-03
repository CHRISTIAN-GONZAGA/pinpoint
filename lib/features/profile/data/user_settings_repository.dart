import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/profile/data/user_settings_remote_datasource.dart';

class UserSettingsRepository {
  UserSettingsRepository({
    required UserSettingsRemoteDataSource remote,
    required ApiClient apiClient,
  })  : _remote = remote,
        _apiClient = apiClient;

  final UserSettingsRemoteDataSource _remote;
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) async {
    try {
      return await _remote.updateProfile(payload);
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }
}
