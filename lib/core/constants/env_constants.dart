import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment variable access with validation.
/// Required variables throw exceptions if missing.
abstract class EnvConstants {
  /// Required: Supabase project URL
  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_URL is not configured in .env file');
    }
    return value;
  }

  /// Required: Supabase anonymous key
  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not configured in .env file');
    }
    return value;
  }

  /// Optional: Sentry DSN for error tracking
  static String get sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';

  /// Optional: PostHog API key for analytics
  static String get posthogApiKey => dotenv.env['POSTHOG_API_KEY'] ?? '';

  /// Optional: PostHog host URL
  static String get posthogHost =>
      dotenv.env['POSTHOG_HOST'] ?? 'https://app.posthog.com';

  /// Optional: CDN URL for static assets
  static String get cdnUrl => dotenv.env['CDN_URL'] ?? '';

  /// Environment name (development, staging, production)
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';

  /// Check if running in production
  static bool get isProduction => environment == 'production';

  // Cloudflare R2 (optional - only needed for file uploads)
  static String get r2Endpoint => dotenv.env['R2_ENDPOINT'] ?? '';
  static String get r2AccessKey => dotenv.env['R2_ACCESS_KEY'] ?? '';
  static String get r2SecretKey => dotenv.env['R2_SECRET_KEY'] ?? '';
  static String get r2BucketName => dotenv.env['R2_BUCKET_NAME'] ?? '';
}
