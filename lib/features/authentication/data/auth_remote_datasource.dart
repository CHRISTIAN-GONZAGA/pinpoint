import 'package:dio/dio.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/authentication/data/auth_local_datasource.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

/// Remote authentication API operations.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required ApiClient apiClient,
    required AuthLocalDataSource localDataSource,
  })  : _api = apiClient.dio,
        _local = localDataSource;

  final Dio _api;
  final AuthLocalDataSource _local;

  Future<User> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return _parseAuthResponse(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    String? mobileNumber,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
          if (mobileNumber != null && mobileNumber.isNotEmpty)
            'mobile_number': mobileNumber,
        },
      );
      return _parseAuthResponse(response.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<User> getProfile() async {
    try {
      final response = await _api.get<Map<String, dynamic>>('/users/profile');
      final data = response.data;
      if (data == null) throw const AppException('Invalid profile response');
      return User.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _api.post<void>('/auth/logout');
    } on DioException {
      // Clear local session even if remote logout fails.
    } finally {
      await _local.clearTokens();
    }
  }

  Future<String?> requestPasswordReset(String email) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/forgot-password',
        data: {'email': email},
      );
      return response.data?['reset_token'] as String?;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      await _api.post<Map<String, dynamic>>(
        '/auth/reset-password',
        data: {'token': token, 'password': password},
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _api.delete<void>('/users/account');
    } on DioException catch (e) {
      throw _mapError(e);
    } finally {
      await _local.clearTokens();
      await _local.setBiometricUnlockEnabled(false);
    }
  }

  Future<User> _parseAuthResponse(Map<String, dynamic>? data) async {
    if (data == null) throw const AppException('Invalid authentication response');
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw const AppException('Missing authentication tokens');
    }
    await _local.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    final userJson = data['user'] as Map<String, dynamic>?;
    if (userJson != null) return User.fromJson(userJson);
    return getProfile();
  }

  AppException _mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    var message = 'Authentication failed. Please try again.';
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    }
    return AppException(message, statusCode: statusCode);
  }
}
