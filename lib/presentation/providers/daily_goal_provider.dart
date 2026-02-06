import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readeng/presentation/providers/book_provider.dart';
import 'package:readeng/presentation/providers/daily_review_provider.dart';
import 'package:readeng/presentation/providers/user_provider.dart';

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

  const DailyGoalState({
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyReviewCompleted,
    required this.wordsReadToday,
    required this.wordsGoal,
    required this.correctAnswersToday,
    required this.answersGoal,
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

  return DailyGoalState(
    currentStreak: user?.currentStreak ?? 0,
    longestStreak: user?.longestStreak ?? 0,
    dailyReviewCompleted: reviewSession != null,
    wordsReadToday: wordsReadToday,
    wordsGoal: DailyGoalConfig.wordsGoal,
    correctAnswersToday: correctAnswersToday,
    answersGoal: DailyGoalConfig.answersGoal,
  );
});

/// Provider for just the streak value (for optimized rebuilds)
final currentStreakProvider = Provider<int>((ref) {
  final userAsync = ref.watch(userControllerProvider);
  return userAsync.valueOrNull?.currentStreak ?? 0;
});
