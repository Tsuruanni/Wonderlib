// lib/presentation/providers/profile_context_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_provider.dart';

/// Resolved school + class names for the current user's profile display.
class ProfileContext {
  const ProfileContext({this.schoolName, this.className});
  final String? schoolName;
  final String? className;
}

/// Fetches the current user's school name and class name by UUID.
/// Note: Direct Supabase query (bypasses UseCase layer) — pragmatic choice
/// for two simple single-row lookups that don't warrant full UseCase/Repo plumbing.
final profileContextProvider = FutureProvider<ProfileContext>((ref) async {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user == null) return const ProfileContext();

  final supabase = Supabase.instance.client;
  String? schoolName;
  String? className;

  try {
    final schoolResult = await supabase
        .from(DbTables.schools)
        .select('name')
        .eq('id', user.schoolId)
        .maybeSingle();
    schoolName = schoolResult?['name'] as String?;
  } catch (_) {}

  if (user.classId != null) {
    try {
      final classResult = await supabase
          .from(DbTables.classes)
          .select('name')
          .eq('id', user.classId!)
          .maybeSingle();
      className = classResult?['name'] as String?;
    } catch (_) {}
  }

  return ProfileContext(schoolName: schoolName, className: className);
});
