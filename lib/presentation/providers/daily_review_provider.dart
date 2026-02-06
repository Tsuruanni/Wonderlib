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

/// Minimum words needed to start a daily review session
const int minDailyReviewCount = 10;

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
    (words) => words.take(30).toList(),
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
    this.requeueCount = const {},
    this.originalWordCount = 0,
  });

  final bool isLoading;
  final List<VocabularyWord> words;
  final Map<String, VocabularyProgress> progressMap;
  final int currentIndex;
  final int correctCount;
  final int incorrectCount;
  final List<SM2Response> responses;
  final DailyReviewResult? sessionResult;
  final Map<String, int> requeueCount;
  final int originalWordCount;

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

  /// Unique words reviewed so far (excludes re-queue duplicates)
  int get uniqueWordsReviewed {
    final seen = <String>{};
    for (var i = 0; i < currentIndex && i < words.length; i++) {
      seen.add(words[i].id);
    }
    return seen.length;
  }

  DailyReviewState copyWith({
    bool? isLoading,
    List<VocabularyWord>? words,
    Map<String, VocabularyProgress>? progressMap,
    int? currentIndex,
    int? correctCount,
    int? incorrectCount,
    List<SM2Response>? responses,
    DailyReviewResult? sessionResult,
    Map<String, int>? requeueCount,
    int? originalWordCount,
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
      requeueCount: requeueCount ?? this.requeueCount,
      originalWordCount: originalWordCount ?? this.originalWordCount,
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
  ///
  /// Session building: max 25 words total.
  /// - Up to 20 non-mastered (learning/reviewing) — most overdue first
  /// - Up to 5 mastered reinforcement — fills remaining slots
  /// Words arrive pre-sorted by overdue priority from the repository.
  Future<void> loadSession() async {
    state = state.copyWith(isLoading: true);

    // Get due words (up to 30, ordered by most overdue first)
    final wordsResult = await getDueForReviewUseCase(
      GetDueForReviewParams(userId: userId),
    );

    final allDueWords = wordsResult.fold(
      (failure) => <VocabularyWord>[],
      (words) => words,
    );

    if (allDueWords.isEmpty) {
      state = state.copyWith(isLoading: false, words: []);
      return;
    }

    // Get progress for each word
    final progressMap = <String, VocabularyProgress>{};
    for (final word in allDueWords) {
      final progressResult = await getWordProgressUseCase(
        GetWordProgressParams(userId: userId, wordId: word.id),
      );
      progressResult.fold(
        (failure) {},
        (progress) => progressMap[word.id] = progress,
      );
    }

    // Split into mastered and non-mastered (preserve overdue order)
    final nonMastered = <VocabularyWord>[];
    final mastered = <VocabularyWord>[];
    for (final word in allDueWords) {
      if (progressMap[word.id]?.isMastered ?? false) {
        mastered.add(word);
      } else {
        nonMastered.add(word);
      }
    }

    // Build session: max 20 non-mastered + max 5 mastered = max 25
    const maxNonMastered = 20;
    const maxMastered = 5;
    const maxTotal = 25;

    final selectedNonMastered = nonMastered.take(maxNonMastered).toList();
    final remainingSlots = maxTotal - selectedNonMastered.length;
    final masteredSlots = remainingSlots.clamp(0, maxMastered);
    final selectedMastered = mastered.take(masteredSlots).toList();

    final words = [...selectedNonMastered, ...selectedMastered];

    // Filter progressMap to only selected words
    final selectedProgressMap = <String, VocabularyProgress>{};
    for (final word in words) {
      if (progressMap.containsKey(word.id)) {
        selectedProgressMap[word.id] = progressMap[word.id]!;
      }
    }

    state = state.copyWith(
      isLoading: false,
      words: words,
      progressMap: selectedProgressMap,
      originalWordCount: words.length,
      currentIndex: 0,
      correctCount: 0,
      incorrectCount: 0,
      responses: [],
      requeueCount: {},
    );
  }

  /// Answer current word with SM2 response
  ///
  /// Re-queue logic: When user answers "Hard" (dontKnow), the word is
  /// appended to the end of the queue (max 2 re-queues per word).
  /// The DB is NOT updated during re-queue — only on the final answer
  /// or when max re-queues are exhausted.
  Future<void> answerWord(SM2Response response) async {
    final currentWord = state.currentWord;
    if (currentWord == null) return;

    final isCorrect = response != SM2Response.dontKnow;
    final newCorrectCount = state.correctCount + (isCorrect ? 1 : 0);
    final newIncorrectCount = state.incorrectCount + (isCorrect ? 0 : 1);

    // Re-queue: "bilmiyorum" → append word to end, skip DB write
    if (!isCorrect) {
      final wordId = currentWord.id;
      final timesRequeued = state.requeueCount[wordId] ?? 0;

      if (timesRequeued < 2) {
        // Append to end, do NOT write to DB (progressMap stays original)
        state = state.copyWith(
          words: [...state.words, currentWord],
          requeueCount: {...state.requeueCount, wordId: timesRequeued + 1},
          currentIndex: state.currentIndex + 1,
          incorrectCount: newIncorrectCount,
          correctCount: newCorrectCount,
          responses: [...state.responses, response],
        );
        return;
      }
      // Max re-queues exhausted → fall through to normal DB write
    }

    // Normal flow: write to DB (correct answer OR max re-queue exceeded)
    // progressMap[wordId] holds the ORIGINAL value (never updated during re-queue)
    final currentProgress = state.progressMap[currentWord.id];
    if (currentProgress != null) {
      final updatedProgress = currentProgress.calculateNextReview(
        response.toQuality(),
      );

      await updateWordProgressUseCase(
        UpdateWordProgressParams(progress: updatedProgress),
      );

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
        wordsReviewed: state.originalWordCount,
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
