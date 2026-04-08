import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sm2_algorithm.dart';
import '../../domain/entities/daily_review_session.dart';
import '../../domain/entities/vocabulary.dart';
import '../../domain/usecases/vocabulary/complete_daily_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_today_review_session_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_batch_usecase.dart';
import '../../domain/usecases/vocabulary/update_word_progress_usecase.dart';
import '../../domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
import 'auth_provider.dart';

import 'usecase_providers.dart';

/// Minimum words needed to start a daily review session
const int minDailyReviewCount = 10;

/// Whether a daily review session is actively in progress (at least one card answered).
/// Used by the shell to guard sidebar/bottom-nav navigation.
final dailyReviewActiveProvider = StateProvider<bool>((ref) => false);

// ============================================================
// Daily Review Providers
// ============================================================

/// Get words due for daily review (max 20)
final dailyReviewWordsProvider = FutureProvider.autoDispose<List<VocabularyWord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getDueForReviewUseCaseProvider);
  final result = await useCase(GetDueForReviewParams(userId: userId));

  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Check if user has already completed today's review
final todayReviewSessionProvider = FutureProvider.autoDispose<DailyReviewSession?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getTodayReviewSessionUseCaseProvider);
  final result = await useCase(GetTodayReviewSessionParams(userId: userId));

  return result.fold(
    (failure) => null,
    (session) => session,
  );
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
    this.firstPassCorrectCount = 0,
    this.firstPassIncorrectCount = 0,
    this.responses = const [],
    this.sessionResult,
    this.requeueCount = const {},
    this.originalWordCount = 0,
    this.isUnitReview = false,
    this.errorMessage,
  });

  final bool isLoading;
  final List<VocabularyWord> words;
  final Map<String, VocabularyProgress> progressMap;
  final int currentIndex;
  final int correctCount;
  final int incorrectCount;
  final int firstPassCorrectCount;
  final int firstPassIncorrectCount;
  final List<SM2Response> responses;
  final DailyReviewResult? sessionResult;
  final Map<String, int> requeueCount;
  final int originalWordCount;
  final bool isUnitReview;
  final String? errorMessage;

  bool get isComplete => currentIndex >= words.length;
  VocabularyWord? get currentWord =>
      words.isNotEmpty && currentIndex < words.length
          ? words[currentIndex]
          : null;
  double get accuracy =>
      (firstPassCorrectCount + firstPassIncorrectCount) > 0
          ? firstPassCorrectCount / (firstPassCorrectCount + firstPassIncorrectCount)
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
    int? firstPassCorrectCount,
    int? firstPassIncorrectCount,
    List<SM2Response>? responses,
    DailyReviewResult? sessionResult,
    Map<String, int>? requeueCount,
    int? originalWordCount,
    bool? isUnitReview,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DailyReviewState(
      isLoading: isLoading ?? this.isLoading,
      words: words ?? this.words,
      progressMap: progressMap ?? this.progressMap,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      firstPassCorrectCount: firstPassCorrectCount ?? this.firstPassCorrectCount,
      firstPassIncorrectCount: firstPassIncorrectCount ?? this.firstPassIncorrectCount,
      responses: responses ?? this.responses,
      sessionResult: sessionResult ?? this.sessionResult,
      requeueCount: requeueCount ?? this.requeueCount,
      originalWordCount: originalWordCount ?? this.originalWordCount,
      isUnitReview: isUnitReview ?? this.isUnitReview,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller for daily review session
class DailyReviewController extends StateNotifier<DailyReviewState> {
  DailyReviewController({
    required this.userId,
    required this.getDueForReviewUseCase,
    required this.getWordProgressBatchUseCase,
    required this.updateWordProgressUseCase,
    required this.completeDailyReviewUseCase,
    required this.getAllWordListsUseCase,
    required this.getWordsForListUseCase,
  }) : super(const DailyReviewState());

  bool _isProcessingAnswer = false;
  final List<VocabularyProgress> _pendingUpdates = [];
  final String userId;
  final GetDueForReviewUseCase getDueForReviewUseCase;
  final GetWordProgressBatchUseCase getWordProgressBatchUseCase;
  final UpdateWordProgressUseCase updateWordProgressUseCase;
  final CompleteDailyReviewUseCase completeDailyReviewUseCase;
  final GetAllWordListsUseCase getAllWordListsUseCase;
  final GetWordsForListUseCase getWordsForListUseCase;

  /// Load words for review session
  Future<void> loadSession() async {
    if (userId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'Not authenticated');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);

    final wordsResult = await getDueForReviewUseCase(
      GetDueForReviewParams(userId: userId),
    );

    final allDueWords = wordsResult.fold(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return <VocabularyWord>[];
      },
      (words) => words,
    );

    if (state.errorMessage != null) return;

    if (allDueWords.isEmpty) {
      state = state.copyWith(isLoading: false, words: []);
      return;
    }

    final wordIds = allDueWords.map((w) => w.id).toList();
    final progressResult = await getWordProgressBatchUseCase(
      GetWordProgressBatchParams(userId: userId, wordIds: wordIds),
    );
    final progressMap = progressResult.fold(
      (_) => <String, VocabularyProgress>{},
      (list) => {for (final p in list) p.wordId: p},
    );

    // RPC now returns only non-mastered words. Take up to 25.
    final words = allDueWords.take(25).toList();

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

  /// Loads ALL words in a specific unit for a "Cram/Review" session.
  /// Ignores SRS due dates and daily limits.
  Future<void> loadUnitReviewSession(String unitId) async {
    if (userId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'Not authenticated');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);

    final allListsResult = await getAllWordListsUseCase(
      GetAllWordListsParams(unitId: unitId),
    );

    final unitListIds = allListsResult.fold(
      (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.message);
        return <String>[];
      },
      (lists) => lists.map((l) => l.id).toList(),
    );

    if (state.errorMessage != null) return;

    if (unitListIds.isEmpty) {
      state = state.copyWith(isLoading: false, words: []);
      return;
    }

    final futureWords = unitListIds.map((listId) =>
      getWordsForListUseCase(GetWordsForListParams(listId: listId))
    );

    final results = await Future.wait(futureWords);
    final allWords = <VocabularyWord>[];

    for (final result in results) {
      result.fold(
        (f) {},
        (words) => allWords.addAll(words),
      );
    }

    final uniqueWords = {for (var w in allWords) w.id: w}.values.toList();
    uniqueWords.shuffle();

    final wordIds = uniqueWords.map((w) => w.id).toList();
    final batchResult = await getWordProgressBatchUseCase(
      GetWordProgressBatchParams(userId: userId, wordIds: wordIds),
    );
    final progressMap = batchResult.fold(
      (_) => <String, VocabularyProgress>{},
      (list) => {for (final p in list) p.wordId: p},
    );

    state = state.copyWith(
      isLoading: false,
      words: uniqueWords,
      progressMap: progressMap,
      originalWordCount: uniqueWords.length,
      currentIndex: 0,
      correctCount: 0,
      incorrectCount: 0,
      responses: [],
      requeueCount: {},
      isUnitReview: true,
    );
  }

  /// Answer current word with SM2 response
  ///
  /// First-answer-wins: The FIRST response for each word is written to DB
  /// immediately. If the user said "Hard", the word is re-queued for
  /// reinforcement (max 2 times), but subsequent answers do NOT update
  /// the SM-2 progress — the first impression is what counts.
  Future<void> answerWord(SM2Response response) async {
    if (_isProcessingAnswer) return;
    final currentWord = state.currentWord;
    if (currentWord == null) return;
    _isProcessingAnswer = true;

    try {
      final isCorrect = response != SM2Response.dontKnow;
      final newCorrectCount = state.correctCount + (isCorrect ? 1 : 0);
      final newIncorrectCount = state.incorrectCount + (isCorrect ? 0 : 1);

      final wordId = currentWord.id;
      final timesRequeued = state.requeueCount[wordId] ?? 0;
      final isRequeued = timesRequeued > 0;

      // Re-queued word: skip DB write (first answer already saved)
      if (isRequeued) {
        final shouldRequeue = !isCorrect && timesRequeued < 2;
        state = state.copyWith(
          words: shouldRequeue ? [...state.words, currentWord] : null,
          requeueCount: shouldRequeue
              ? {...state.requeueCount, wordId: timesRequeued + 1}
              : null,
          currentIndex: state.currentIndex + 1,
          correctCount: newCorrectCount,
          incorrectCount: newIncorrectCount,
          responses: [...state.responses, response],
        );
        return;
      }

      // First time seeing this word: calculate SM-2 and defer DB write
      final newFirstCorrect = state.firstPassCorrectCount + (isCorrect ? 1 : 0);
      final newFirstIncorrect = state.firstPassIncorrectCount + (isCorrect ? 0 : 1);

      final currentProgress = state.progressMap[wordId];

      // Build progress: use existing or create initial SM-2 values
      final baseProgress = currentProgress ?? VocabularyProgress(
        id: '',
        userId: userId,
        wordId: wordId,
        easeFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
        nextReviewAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final updatedProgress = SM2.calculateNextReview(
        baseProgress,
        response.toQuality(),
      );

      _pendingUpdates.add(updatedProgress);

      final newProgressMap = Map<String, VocabularyProgress>.from(state.progressMap);
      newProgressMap[wordId] = updatedProgress;

      final shouldRequeue = !isCorrect;
      state = state.copyWith(
        progressMap: newProgressMap,
        words: shouldRequeue ? [...state.words, currentWord] : null,
        requeueCount: shouldRequeue
            ? {...state.requeueCount, wordId: 1}
            : null,
        currentIndex: state.currentIndex + 1,
        correctCount: newCorrectCount,
        incorrectCount: newIncorrectCount,
        firstPassCorrectCount: newFirstCorrect,
        firstPassIncorrectCount: newFirstIncorrect,
        responses: [...state.responses, response],
      );
    } finally {
      _isProcessingAnswer = false;
    }
  }

  /// Flush all pending SM-2 progress updates to DB.
  /// Called only when the full session is completed (all cards answered).
  Future<void> flushPendingProgress() async {
    for (final progress in _pendingUpdates) {
      await updateWordProgressUseCase(
        UpdateWordProgressParams(progress: progress),
      );
    }
    _pendingUpdates.clear();
  }

  /// Complete session and award XP (uses first-pass counts only)
  Future<DailyReviewResult?> completeSession() async {
    await flushPendingProgress();
    final result = await completeDailyReviewUseCase(
      CompleteDailyReviewParams(
        userId: userId,
        wordsReviewed: state.originalWordCount,
        correctCount: state.firstPassCorrectCount,
        incorrectCount: state.firstPassIncorrectCount,
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
      final controller = DailyReviewController(
        userId: '',
        getDueForReviewUseCase: ref.watch(getDueForReviewUseCaseProvider),
        getWordProgressBatchUseCase: ref.watch(getWordProgressBatchUseCaseProvider),
        updateWordProgressUseCase: ref.watch(updateWordProgressUseCaseProvider),
        completeDailyReviewUseCase: ref.watch(completeDailyReviewUseCaseProvider),
        getAllWordListsUseCase: ref.watch(getAllWordListsUseCaseProvider),
        getWordsForListUseCase: ref.watch(getWordsForListUseCaseProvider),
      );
      return controller;
    }

    return DailyReviewController(
      userId: userId,
      getDueForReviewUseCase: ref.watch(getDueForReviewUseCaseProvider),
      getWordProgressBatchUseCase: ref.watch(getWordProgressBatchUseCaseProvider),
      updateWordProgressUseCase: ref.watch(updateWordProgressUseCaseProvider),
      completeDailyReviewUseCase: ref.watch(completeDailyReviewUseCaseProvider),
      getAllWordListsUseCase: ref.watch(getAllWordListsUseCaseProvider),
      getWordsForListUseCase: ref.watch(getWordsForListUseCaseProvider),
    );
  },
);
