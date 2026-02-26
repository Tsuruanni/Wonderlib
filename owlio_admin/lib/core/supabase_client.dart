import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration for admin panel.
/// Uses the same Supabase project as the main app.
class SupabaseConfig {
  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_URL is not configured in .env file');
    }
    return value;
  }

  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not configured in .env file');
    }
    return value;
  }

  static String get elevenLabsApiKey {
    return dotenv.env['ELEVENLABS_API_KEY'] ?? '';
  }

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

/// Provider for Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

/// Provider for current admin user
final currentAdminUserProvider = StreamProvider<User?>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentAdminUserProvider);
  return user.valueOrNull != null;
});

/// Provider for current user's role (fetched from profiles table)
final currentUserRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentAdminUserProvider).valueOrNull;
  if (user == null) return null;
  final supabase = ref.watch(supabaseClientProvider);
  final profile = await supabase
      .from(DbTables.profiles)
      .select('role')
      .eq('id', user.id)
      .maybeSingle();
  return profile?['role'] as String?;
});

/// Whether current user is admin or head teacher
final isAuthorizedAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider).valueOrNull;
  if (role == null) return false;
  return role == UserRole.admin.dbValue || role == UserRole.head.dbValue;
});
