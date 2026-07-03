import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/features/authentication/data/auth_local_datasource.dart';

/// HTTP client configured for the PINPOINT REST API.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required AuthLocalDataSource authLocal,
  })  : _authLocal = authLocal,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authLocal.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('[API] ${options.method} ${options.uri}');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final token = await _authLocal.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch<dynamic>(error.requestOptions);
              handler.resolve(response);
              return;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthLocalDataSource _authLocal;

  Dio get dio => _dio;

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _authLocal.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      final data = response.data;
      if (data == null) return false;
      await _authLocal.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String? ?? refreshToken,
      );
      return true;
    } catch (_) {
      await _authLocal.clearTokens();
      return false;
    }
  }

  AppException mapError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String message = 'Something went wrong. Please try again.';
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      message = 'Connection lost. Please check your internet.';
    }
    if (statusCode == 401) return AuthException(message, statusCode);
    if (statusCode != null && statusCode >= 500) {
      return AppException('Server unavailable. Please try again later.', statusCode: statusCode);
    }
    return AppException(message, statusCode: statusCode);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('ApiClient must be overridden in dependency_injection.dart');
});
