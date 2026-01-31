import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/activity.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Provides activities for a chapter
final chapterActivitiesProvider =
    FutureProvider.family<List<Activity>, String>((ref, chapterId) async {
  final activityRepo = ref.watch(activityRepositoryProvider);
  final result = await activityRepo.getActivitiesByChapter(chapterId);
  return result.fold(
    (failure) => [],
    (activities) => activities,
  );
});

/// Provides a single activity by ID
final activityByIdProvider =
    FutureProvider.family<Activity?, String>((ref, activityId) async {
  final activityRepo = ref.watch(activityRepositoryProvider);
  final result = await activityRepo.getActivityById(activityId);
  return result.fold(
    (failure) => null,
    (activity) => activity,
  );
});

/// Provides best result for an activity
final activityBestResultProvider =
    FutureProvider.family<ActivityResult?, String>((ref, activityId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final activityRepo = ref.watch(activityRepositoryProvider);
  final result = await activityRepo.getBestResult(
    userId: userId,
    activityId: activityId,
  );
  return result.fold(
    (failure) => null,
    (result) => result,
  );
});

/// Provides activity stats for current user
final activityStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final activityRepo = ref.watch(activityRepositoryProvider);
  final result = await activityRepo.getActivityStats(userId);
  return result.fold(
    (failure) => {},
    (stats) => stats,
  );
});

/// Activity session controller
class ActivitySessionController extends StateNotifier<ActivitySessionState> {
  final Ref _ref;
  final String activityId;
  final _uuid = const Uuid();

  ActivitySessionController(this._ref, this.activityId)
      : super(const ActivitySessionState()) {
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    state = state.copyWith(isLoading: true);

    final activityRepo = _ref.read(activityRepositoryProvider);
    final result = await activityRepo.getActivityById(activityId);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (activity) {
        state = state.copyWith(
          isLoading: false,
          activity: activity,
          answers: {},
          startTime: DateTime.now(),
        );
      },
    );
  }

  void answerQuestion(String questionId, dynamic answer) {
    final newAnswers = Map<String, dynamic>.from(state.answers);
    newAnswers[questionId] = answer;
    state = state.copyWith(answers: newAnswers);
  }

  Future<ActivityResult?> submitAnswers() async {
    final userId = _ref.read(currentUserIdProvider);
    final activity = state.activity;
    if (userId == null || activity == null) return null;

    state = state.copyWith(isSubmitting: true);

    // Calculate score
    double score = 0;
    double maxScore = 0;

    for (final question in activity.questions) {
      maxScore += question.points;
      final userAnswer = state.answers[question.id];
      if (question.checkAnswer(userAnswer)) {
        score += question.points;
      }
    }

    // Calculate time spent
    final timeSpent = state.startTime != null
        ? DateTime.now().difference(state.startTime!).inSeconds
        : 0;

    final result = ActivityResult(
      id: _uuid.v4(),
      userId: userId,
      activityId: activityId,
      score: score,
      maxScore: maxScore,
      answers: state.answers,
      timeSpent: timeSpent,
      attemptNumber: 1, // TODO: Track attempts
      completedAt: DateTime.now(),
    );

    final activityRepo = _ref.read(activityRepositoryProvider);
    final submitResult = await activityRepo.submitActivityResult(result);

    if (submitResult.isLeft()) {
      final failure = submitResult.fold((f) => f, (_) => null)!;
      state = state.copyWith(isSubmitting: false, error: failure.message);
      return null;
    }

    final activityResult = submitResult.fold((_) => null, (r) => r)!;

    // Refresh user data to update XP in UI
    await refreshUserData(_ref);

    state = state.copyWith(
      isSubmitting: false,
      isComplete: true,
      result: activityResult,
    );
    return activityResult;
  }

  void reset() {
    _loadActivity();
  }
}

class ActivitySessionState {
  final bool isLoading;
  final bool isSubmitting;
  final bool isComplete;
  final String? error;
  final Activity? activity;
  final Map<String, dynamic> answers;
  final DateTime? startTime;
  final ActivityResult? result;

  const ActivitySessionState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isComplete = false,
    this.error,
    this.activity,
    this.answers = const {},
    this.startTime,
    this.result,
  });

  int get answeredCount => answers.length;
  int get totalQuestions => activity?.questions.length ?? 0;
  bool get canSubmit => answeredCount == totalQuestions && !isSubmitting;

  ActivitySessionState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isComplete,
    String? error,
    Activity? activity,
    Map<String, dynamic>? answers,
    DateTime? startTime,
    ActivityResult? result,
  }) {
    return ActivitySessionState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isComplete: isComplete ?? this.isComplete,
      error: error,
      activity: activity ?? this.activity,
      answers: answers ?? this.answers,
      startTime: startTime ?? this.startTime,
      result: result ?? this.result,
    );
  }
}

final activitySessionControllerProvider = StateNotifierProvider.family<
    ActivitySessionController, ActivitySessionState, String>((ref, activityId) {
  return ActivitySessionController(ref, activityId);
});
