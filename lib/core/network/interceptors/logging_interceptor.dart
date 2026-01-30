import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// Interceptor for logging HTTP requests/responses in debug mode
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log('→ ${options.method} ${options.uri}');
    if (options.data != null) {
      _log('  Body: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log('✕ ${err.response?.statusCode ?? 'ERR'} ${err.requestOptions.uri}');
    _log('  Error: ${err.message}');
    handler.next(err);
  }

  void _log(String message) {
    // Only log in debug mode
    assert(() {
      developer.log(message, name: 'API');
      return true;
    }());
  }
}
