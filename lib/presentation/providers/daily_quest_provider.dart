import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/daily_quest.dart';
import '../../domain/usecases/daily_quest/get_daily_quest_progress_usecase.dart';
import '../../domain/usecases/daily_quest/has_daily_bonus_claimed_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Provides daily quest progress for the current user.
/// Returns list of DailyQuestProgress from server-side RPC.
final dailyQuestProgressProvider = FutureProvider<List<DailyQuestProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getDailyQuestProgressUseCaseProvider);
  final result = await useCase(GetDailyQuestProgressParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('dailyQuestProgressProvider error: ${failure.message}');
      return [];
    },
    (progress) => progress,
  );
});

/// Whether the daily bonus (all-quests-complete pack) has been claimed today.
final dailyBonusClaimedProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final useCase = ref.watch(hasDailyBonusClaimedUseCaseProvider);
  final result = await useCase(HasDailyBonusClaimedParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('dailyBonusClaimedProvider error: ${failure.message}');
      return false;
    },
    (claimed) => claimed,
  );
});
