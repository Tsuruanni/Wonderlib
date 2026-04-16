import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_provider.dart';

/// Count of `activity_results` rows where the user achieved a perfect score
/// (score equal to max_score). Used to compute progress for `perfect_scores`
/// condition badges.
///
/// Implementation note: Supabase PostgREST builder cannot express column-to-column
/// equality (`score = max_score`), so we fetch both fields for this user's rows
/// and filter client-side. Acceptable for individual users with bounded history.
final perfectScoresCountProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;

  try {
    final response = await Supabase.instance.client
        .from(DbTables.activityResults)
        .select('score, max_score')
        .eq('user_id', userId);

    final rows = response as List;
    return rows.where((r) {
      final map = r as Map<String, dynamic>;
      final score = map['score'];
      final maxScore = map['max_score'];
      return score != null && maxScore != null && score == maxScore;
    }).length;
  } catch (_) {
    return 0;
  }
});
