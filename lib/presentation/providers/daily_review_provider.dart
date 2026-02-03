import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sm2_algorithm.dart';
import '../../domain/entities/daily_review_session.dart';
import '../../domain/entities/vocabulary.dart';
import '../../domain/usecases/vocabulary/complete_daily_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_today_review_session_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/update_word_progress_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

// ============================================================
// Daily Review Providers
// ============================================================

/// Get words due for daily review (max 20)
final dailyReviewWordsProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getDueForReviewUseCaseProvider);
  final result = await useCase(GetDueForReviewParams(userId: userId));

  return result.fold(
    (failure) => [],
    (words) => words.take(20).toList(),
  );
});

/// Check if user has already completed today's review
final todayReviewSessionProvider = FutureProvider<DailyReviewSession?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getTodayReviewSessionUseCaseProvider);
  final result = await useCase(GetTodayReviewSessionParams(userId: userId));

  return result.fold(
    (failure) => null,
    (session) => session,
  );
});

/// Total due words count for UI display
final totalDueWordsForReviewProvider = FutureProvider<int>((ref) async {
  final words = await ref.watch(dailyReviewWordsProvider.future);
  return words.length;
});

// ============================================================
// Daily Review State & Controller
// ============================================================

/// State for daily review session
class DailyReviewState {
  const DailyReviewState({
    this.isLoading = true,
    this.words = const [],
    this.progressMap = const {},
    this.currentIndex = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.responses = const [],
    this.sessionResult,
  });

  final bool isLoading;
  final List<VocabularyWord> words;
  final Map<String, VocabularyProgress> progressMap;
  final int currentIndex;
  final int correctCount;
  final int incorrectCount;
  final List<SM2Response> responses;
  final DailyReviewResult? sessionResult;

  bool get isComplete => currentIndex >= words.length;
  VocabularyWord? get currentWord =>
      words.isNotEmpty && currentIndex < words.length
          ? words[currentIndex]
          : null;
  double get accuracy =>
      (correctCount + incorrectCount) > 0
          ? correctCount / (correctCount + incorrectCount)
          : 0.0;
  int get totalReviewed => correctCount + incorrectCount;

  DailyReviewState copyWith({
    bool? isLoading,
    List<VocabularyWord>? words,
    Map<String, VocabularyProgress>? progressMap,
    int? currentIndex,
    int? correctCount,
    int? incorrectCount,
    List<SM2Response>? responses,
    DailyReviewResult? sessionResult,
  }) {
    return DailyReviewState(
      isLoading: isLoading ?? this.isLoading,
      words: words ?? this.words,
      progressMap: progressMap ?? this.progressMap,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      responses: responses ?? this.responses,
      sessionResult: sessionResult ?? this.sessionResult,
    );
  }
}

/// Controller for daily review session
class DailyReviewController extends StateNotifier<DailyReviewState> {
  DailyReviewController({
    required this.userId,
    required this.getDueForReviewUseCase,
    required this.getWordProgressUseCase,
    required this.updateWordProgressUseCase,
    required this.completeDailyReviewUseCase,
  }) : super(const DailyReviewState());

  final String userId;
  final GetDueForReviewUseCase getDueForReviewUseCase;
  final GetWordProgressUseCase getWordProgressUseCase;
  final UpdateWordProgressUseCase updateWordProgressUseCase;
  final CompleteDailyReviewUseCase completeDailyReviewUseCase;

  /// Load words for review session
  Future<void> loadSession() async {
    state = state.copyWith(isLoading: true);

    // Get due words
    final wordsResult = await getDueForReviewUseCase(
      GetDueForReviewParams(userId: userId),
    );

    final words = wordsResult.fold(
      (failure) => <VocabularyWord>[],
      (words) => words.take(20).toList(),
    );

    if (words.isEmpty) {
      state = state.copyWith(isLoading: false, words: []);
      return;
    }

    // Get progress for each word
    final progressMap = <String, VocabularyProgress>{};
    for (final word in words) {
      final progressResult = await getWordProgressUseCase(
        GetWordProgressParams(userId: userId, wordId: word.id),
      );
      progressResult.fold(
        (failure) {},
        (progress) => progressMap[word.id] = progress,
      );
    }

    state = state.copyWith(
      isLoading: false,
      words: words,
      progressMap: progressMap,
      currentIndex: 0,
      correctCount: 0,
      incorrectCount: 0,
      responses: [],
    );
  }

  /// Answer current word with SM2 response
  Future<void> answerWord(SM2Response response) async {
    final currentWord = state.currentWord;
    if (currentWord == null) return;

    // Update local counts
    final isCorrect = response != SM2Response.dontKnow;
    final newCorrectCount = state.correctCount + (isCorrect ? 1 : 0);
    final newIncorrectCount = state.incorrectCount + (isCorrect ? 0 : 1);

    // Update progress with SM2 algorithm
    final currentProgress = state.progressMap[currentWord.id];
    if (currentProgress != null) {
      final updatedProgress = currentProgress.calculateNextReview(
        response.toQuality(),
      );

      // Save to database
      await updateWordProgressUseCase(
        UpdateWordProgressParams(progress: updatedProgress),
      );

      // Update local progress map
      final newProgressMap = Map<String, VocabularyProgress>.from(state.progressMap);
      newProgressMap[currentWord.id] = updatedProgress;

      state = state.copyWith(
        progressMap: newProgressMap,
        correctCount: newCorrectCount,
        incorrectCount: newIncorrectCount,
        responses: [...state.responses, response],
        currentIndex: state.currentIndex + 1,
      );
    } else {
      // Just advance if no progress found
      state = state.copyWith(
        correctCount: newCorrectCount,
        incorrectCount: newIncorrectCount,
        responses: [...state.responses, response],
        currentIndex: state.currentIndex + 1,
      );
    }
  }

  /// Complete session and award XP
  Future<DailyReviewResult?> completeSession() async {
    final result = await completeDailyReviewUseCase(
      CompleteDailyReviewParams(
        userId: userId,
        wordsReviewed: state.totalReviewed,
        correctCount: state.correctCount,
        incorrectCount: state.incorrectCount,
      ),
    );

    return result.fold(
      (failure) => null,
      (sessionResult) {
        state = state.copyWith(sessionResult: sessionResult);
        return sessionResult;
      },
    );
  }
}

/// Provider for daily review controller
final dailyReviewControllerProvider =
    StateNotifierProvider.autoDispose<DailyReviewController, DailyReviewState>(
  (ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      throw Exception('User not logged in');
    }

    return DailyReviewController(
      userId: userId,
      getDueForReviewUseCase: ref.watch(getDueForReviewUseCaseProvider),
      getWordProgressUseCase: ref.watch(getWordProgressUseCaseProvider),
      updateWordProgressUseCase: ref.watch(updateWordProgressUseCaseProvider),
      completeDailyReviewUseCase: ref.watch(completeDailyReviewUseCaseProvider),
    );
  },
);
