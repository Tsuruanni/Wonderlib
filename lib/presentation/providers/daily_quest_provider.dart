import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/daily_quest.dart';
import '../../domain/usecases/daily_quest/claim_daily_bonus_usecase.dart';
import '../../domain/usecases/daily_quest/get_daily_quest_progress_usecase.dart';
import '../../domain/usecases/daily_quest/has_daily_bonus_claimed_usecase.dart';
import 'auth_provider.dart';
import 'monthly_quest_provider.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';

/// Event fired when one or more daily quests are newly completed.
class QuestCompletionEvent {
  const QuestCompletionEvent({
    required this.completedQuests,
    required this.allQuestsComplete,
  });

  final List<DailyQuestProgress> completedQuests;
  final bool allQuestsComplete;
}

final questCompletionEventProvider =
    StateProvider<QuestCompletionEvent?>((ref) => null);

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
    (progress) {
      final newlyCompleted =
          progress.where((q) => q.newlyCompleted).toList();
      if (newlyCompleted.isNotEmpty) {
        final allComplete = progress.every((q) => q.isCompleted);
        // Schedule microtask so the event fires after provider settles.
        Future.microtask(() {
          // Skip if an event is already pending (prevents duplicate on rapid invalidations).
          if (ref.read(questCompletionEventProvider) != null) return;
          ref.read(questCompletionEventProvider.notifier).state =
              QuestCompletionEvent(
            completedQuests: newlyCompleted,
            allQuestsComplete: allComplete,
          );
          // Refresh monthly quest so 'complete_daily_quests' counter stays in sync.
          ref.invalidate(monthlyQuestProgressProvider);
        });
      }
      return progress;
    },
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

/// Controller for daily quest mutations (claim bonus).
/// Keeps business logic out of widgets — mirrors AvatarController pattern.
final dailyQuestControllerProvider =
    StateNotifierProvider<DailyQuestController, AsyncValue<void>>((ref) {
  return DailyQuestController(ref);
});

class DailyQuestController extends StateNotifier<AsyncValue<void>> {
  DailyQuestController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  bool get isMutating => state is AsyncLoading;

  /// Claims the daily bonus pack. Returns error message on failure, null on success.
  Future<String?> claimBonus() async {
    if (isMutating) return null;

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return 'Not logged in';

    state = const AsyncValue.loading();

    final useCase = _ref.read(claimDailyBonusUseCaseProvider);
    final result = await useCase(ClaimDailyBonusParams(userId: userId));

    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (_) {
        _ref.invalidate(dailyQuestProgressProvider);
        _ref.invalidate(dailyBonusClaimedProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}
