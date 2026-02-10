import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readeng/domain/usecases/card/has_daily_quest_pack_claimed_usecase.dart';
import 'package:readeng/presentation/providers/book_provider.dart';
import 'package:readeng/presentation/providers/daily_review_provider.dart';
import 'package:readeng/presentation/providers/user_provider.dart';

import 'auth_provider.dart';
import 'usecase_providers.dart';

/// Daily goal configuration
class DailyGoalConfig {
  static const int wordsGoal = 100;
  static const int answersGoal = 5;
}

/// Aggregated state for daily goal widget
class DailyGoalState {
  final int currentStreak;
  final int longestStreak;
  final bool dailyReviewCompleted;
  final int wordsReadToday;
  final int wordsGoal;
  final int correctAnswersToday;
  final int answersGoal;
  final bool packClaimed;

  const DailyGoalState({
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyReviewCompleted,
    required this.wordsReadToday,
    required this.wordsGoal,
    required this.correctAnswersToday,
    required this.answersGoal,
    this.packClaimed = false,
  });

  /// Number of completed tasks (0-3)
  int get completedTasksCount {
    int count = 0;
    if (dailyReviewCompleted) count++;
    if (wordsReadToday >= wordsGoal) count++;
    if (correctAnswersToday >= answersGoal) count++;
    return count;
  }

  /// Total number of tasks
  int get totalTasks => 3;

  /// Overall progress (0.0 - 1.0)
  double get overallProgress => completedTasksCount / totalTasks;

  /// Whether reading goal is completed
  bool get isReadingGoalCompleted => wordsReadToday >= wordsGoal;

  /// Whether activity goal is completed
  bool get isActivityGoalCompleted => correctAnswersToday >= answersGoal;

  /// Reading progress (0.0 - 1.0, capped at 1.0)
  double get readingProgress => (wordsReadToday / wordsGoal).clamp(0.0, 1.0);

  /// Activity progress (0.0 - 1.0, capped at 1.0)
  double get activityProgress =>
      (correctAnswersToday / answersGoal).clamp(0.0, 1.0);

  /// Whether all tasks are completed
  bool get allTasksCompleted => completedTasksCount == totalTasks;

  /// Whether the pack reward can be claimed
  bool get canClaimPack => allTasksCompleted && !packClaimed;

  /// Empty state for loading
  static const DailyGoalState empty = DailyGoalState(
    currentStreak: 0,
    longestStreak: 0,
    dailyReviewCompleted: false,
    wordsReadToday: 0,
    wordsGoal: DailyGoalConfig.wordsGoal,
    correctAnswersToday: 0,
    answersGoal: DailyGoalConfig.answersGoal,
  );
}

/// Whether today's daily quest pack has been claimed
final dailyQuestPackClaimedProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final useCase = ref.watch(hasDailyQuestPackClaimedUseCaseProvider);
  final result = await useCase(HasDailyQuestPackClaimedParams(userId: userId));
  return result.fold(
    (failure) {
      debugPrint('dailyQuestPackClaimedProvider error: ${failure.message}');
      return false;
    },
    (claimed) => claimed,
  );
});

/// Provider that aggregates all daily goal data
final dailyGoalProvider = FutureProvider<DailyGoalState>((ref) async {
  // Get user data for streak
  final userAsync = ref.watch(userControllerProvider);
  final user = userAsync.valueOrNull;

  // Get daily review session
  final reviewSessionAsync = ref.watch(todayReviewSessionProvider);
  final reviewSession = reviewSessionAsync.valueOrNull;

  // Get words read today
  final wordsAsync = ref.watch(wordsReadTodayProvider);
  final wordsReadToday = wordsAsync.valueOrNull ?? 0;

  // Get correct answers today
  final answersAsync = ref.watch(correctAnswersTodayProvider);
  final correctAnswersToday = answersAsync.valueOrNull ?? 0;

  // Get pack claim status
  final packClaimedAsync = ref.watch(dailyQuestPackClaimedProvider);
  final packClaimed = packClaimedAsync.valueOrNull ?? false;

  return DailyGoalState(
    currentStreak: user?.currentStreak ?? 0,
    longestStreak: user?.longestStreak ?? 0,
    dailyReviewCompleted: reviewSession != null,
    wordsReadToday: wordsReadToday,
    wordsGoal: DailyGoalConfig.wordsGoal,
    correctAnswersToday: correctAnswersToday,
    answersGoal: DailyGoalConfig.answersGoal,
    packClaimed: packClaimed,
  );
});

/// Provider for just the streak value (for optimized rebuilds)
final currentStreakProvider = Provider<int>((ref) {
  final userAsync = ref.watch(userControllerProvider);
  return userAsync.valueOrNull?.currentStreak ?? 0;
});
