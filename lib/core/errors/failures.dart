import 'package:equatable/equatable.dart';

/// Base failure class for functional error handling
/// Used with dartz Either<Failure, Success> pattern
abstract class Failure extends Equatable {

  const Failure({
    required this.message,
    this.code,
  });
  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// Server/API failures
class ServerFailure extends Failure {

  const ServerFailure(
    String message, {
    super.code,
    this.statusCode,
  }) : super(message: message);
  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection'])
      : super(message: message, code: 'NO_NETWORK');
}

/// Local cache/database failures
class CacheFailure extends Failure {
  const CacheFailure(String message)
      : super(message: message, code: 'CACHE_ERROR');
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure(String message, {String? code})
      : super(message: message, code: code ?? 'AUTH_ERROR');

  factory AuthFailure.invalidCredentials() => const AuthFailure(
        'Invalid email or password',
        code: 'INVALID_CREDENTIALS',
      );

  factory AuthFailure.schoolNotFound() => const AuthFailure(
        'School not found',
        code: 'SCHOOL_NOT_FOUND',
      );

  factory AuthFailure.sessionExpired() => const AuthFailure(
        'Session expired, please login again',
        code: 'SESSION_EXPIRED',
      );
}

/// Validation failures
class ValidationFailure extends Failure {

  const ValidationFailure(
    String message, {
    this.fieldErrors,
  }) : super(message: message, code: 'VALIDATION_ERROR');
  final Map<String, List<String>>? fieldErrors;

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Sync failures for offline-first operations
class SyncFailure extends Failure {
  const SyncFailure(String message)
      : super(message: message, code: 'SYNC_ERROR');
}

/// Not found failure
class NotFoundFailure extends Failure {
  const NotFoundFailure(String message)
      : super(message: message, code: 'NOT_FOUND');
}

/// Generic unexpected failure
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([String message = 'An unexpected error occurred'])
      : super(message: message, code: 'UNEXPECTED');
}
