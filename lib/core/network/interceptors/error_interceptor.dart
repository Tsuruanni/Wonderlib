import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Interceptor to handle and log errors
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log error to Sentry (except for expected errors like 401, 404)
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      Sentry.captureException(
        err,
        stackTrace: err.stackTrace,
        hint: Hint.withMap({
          'url': err.requestOptions.uri.toString(),
          'method': err.requestOptions.method,
          'statusCode': statusCode.toString(),
        }),
      );
    }

    handler.next(err);
  }
}
