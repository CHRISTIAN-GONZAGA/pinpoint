/// Base class for application-level failures with user-friendly messages.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Connection lost. Please try again.']);
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server unavailable. Please try again later.']);
}

final class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed. Please sign in again.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Unable to load cached data.']);
}

final class LocationFailure extends Failure {
  const LocationFailure([super.message = 'Location unavailable.']);
}
