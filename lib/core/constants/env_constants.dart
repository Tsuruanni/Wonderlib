import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class EnvConstants {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get sentryDsn => dotenv.env['SENTRY_DSN'] ?? '';
  static String get posthogApiKey => dotenv.env['POSTHOG_API_KEY'] ?? '';
  static String get posthogHost => dotenv.env['POSTHOG_HOST'] ?? 'https://app.posthog.com';
  static String get cdnUrl => dotenv.env['CDN_URL'] ?? '';
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';

  // Cloudflare R2
  static String get r2Endpoint => dotenv.env['R2_ENDPOINT'] ?? '';
  static String get r2AccessKey => dotenv.env['R2_ACCESS_KEY'] ?? '';
  static String get r2SecretKey => dotenv.env['R2_SECRET_KEY'] ?? '';
  static String get r2BucketName => dotenv.env['R2_BUCKET_NAME'] ?? '';
}
