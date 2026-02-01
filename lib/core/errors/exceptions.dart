/// Base exception class for all app exceptions
abstract class AppException implements Exception {

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });
  final String message;
  final String? code;
  final dynamic originalError;

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Server/API related exceptions
class ServerException extends AppException {

  const ServerException({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
  });

  factory ServerException.fromStatusCode(int statusCode, [String? message]) {
    switch (statusCode) {
      case 400:
        return ServerException(
          message: message ?? 'Bad request',
          code: 'BAD_REQUEST',
          statusCode: statusCode,
        );
      case 401:
        return ServerException(
          message: message ?? 'Unauthorized',
          code: 'UNAUTHORIZED',
          statusCode: statusCode,
        );
      case 403:
        return ServerException(
          message: message ?? 'Forbidden',
          code: 'FORBIDDEN',
          statusCode: statusCode,
        );
      case 404:
        return ServerException(
          message: message ?? 'Not found',
          code: 'NOT_FOUND',
          statusCode: statusCode,
        );
      case 409:
        return ServerException(
          message: message ?? 'Conflict',
          code: 'CONFLICT',
          statusCode: statusCode,
        );
      case 422:
        return ServerException(
          message: message ?? 'Validation error',
          code: 'VALIDATION_ERROR',
          statusCode: statusCode,
        );
      case 429:
        return ServerException(
          message: message ?? 'Too many requests',
          code: 'RATE_LIMITED',
          statusCode: statusCode,
        );
      case 500:
        return ServerException(
          message: message ?? 'Internal server error',
          code: 'SERVER_ERROR',
          statusCode: statusCode,
        );
      case 503:
        return ServerException(
          message: message ?? 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          statusCode: statusCode,
        );
      default:
        return ServerException(
          message: message ?? 'Unknown server error',
          code: 'UNKNOWN',
          statusCode: statusCode,
        );
    }
  }
  final int? statusCode;
}

/// Network connectivity exceptions
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection',
    super.code = 'NO_NETWORK',
    super.originalError,
  });
}

/// Local database exceptions
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code = 'CACHE_ERROR',
    super.originalError,
  });
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.originalError,
  });

  factory AuthException.invalidCredentials() => const AuthException(
        message: 'Invalid email or password',
        code: 'INVALID_CREDENTIALS',
      );

  factory AuthException.schoolNotFound() => const AuthException(
        message: 'School not found',
        code: 'SCHOOL_NOT_FOUND',
      );

  factory AuthException.sessionExpired() => const AuthException(
        message: 'Session expired, please login again',
        code: 'SESSION_EXPIRED',
      );

  factory AuthException.userNotFound() => const AuthException(
        message: 'User not found',
        code: 'USER_NOT_FOUND',
      );
}

/// Validation exceptions
class ValidationException extends AppException {

  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors,
  });
  final Map<String, List<String>>? fieldErrors;
}

/// Sync exceptions for offline-first operations
class SyncException extends AppException {
  const SyncException({
    required super.message,
    super.code = 'SYNC_ERROR',
    super.originalError,
  });
}
