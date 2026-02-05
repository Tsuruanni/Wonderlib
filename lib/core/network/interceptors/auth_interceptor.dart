import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interceptor to add authentication token to requests
class AuthInterceptor extends Interceptor {

  AuthInterceptor({required SupabaseClient supabase}) : _supabase = supabase;
  final SupabaseClient _supabase;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = _supabase.auth.currentSession;

    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 errors - try to refresh token
    if (err.response?.statusCode == 401) {
      try {
        final response = await _supabase.auth.refreshSession();
        if (response.session != null) {
          // Retry the request with new token
          final options = err.requestOptions;
          options.headers['Authorization'] =
              'Bearer ${response.session!.accessToken}';

          final dio = Dio();
          final retryResponse = await dio.fetch(options);
          return handler.resolve(retryResponse);
        }
      } catch (_) {
        // Refresh failed, continue with error
      }
    }

    handler.next(err);
  }
}
