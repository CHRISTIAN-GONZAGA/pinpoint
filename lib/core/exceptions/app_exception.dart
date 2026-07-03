/// Typed exceptions thrown by data layer implementations.
class AppException implements Exception {
  const AppException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Network error', int? statusCode])
      : super(message, statusCode: statusCode);
}

class AuthException extends AppException {
  const AuthException([String message = 'Authentication error', int? statusCode])
      : super(message, statusCode: statusCode);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Cache error']);
}
