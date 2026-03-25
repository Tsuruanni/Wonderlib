import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sm2_algorithm.dart';
import '../../domain/entities/daily_review_session.dart';
import '../../domain/entities/vocabulary.dart';
import '../../domain/usecases/vocabulary/complete_daily_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_today_review_session_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_batch_usecase.dart';
import '../../domain/usecases/vocabulary/update_word_progress_usecase.dart';
import '../../domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
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
    this.firstPassCorrectCount = 0,
    this.firstPassIncorrectCount = 0,
    this.responses = const [],
    this.sessionResult,
    this.requeueCount = const {},
    this.originalWordCount = 0,
    this.isUnitReview = false,
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
    );
  }
}

/// Controller for daily review session
class DailyReviewController extends StateNotifier<DailyReviewState> {
  DailyReviewController({
    required this.userId,
    required this.getDueForReviewUseCase,
    required this.getWordProgressUseCase,
    required this.getWordProgressBatchUseCase,
    required this.updateWordProgressUseCase,
    required this.completeDailyReviewUseCase,
    required this.getAllWordListsUseCase,
    required this.getWordsForListUseCase,
  }) : super(const DailyReviewState());

  bool _isProcessingAnswer = false;
  final String userId;
  final GetDueForReviewUseCase getDueForReviewUseCase;
  final GetWordProgressUseCase getWordProgressUseCase;
  final GetWordProgressBatchUseCase getWordProgressBatchUseCase;
  final UpdateWordProgressUseCase updateWordProgressUseCase;
  final CompleteDailyReviewUseCase completeDailyReviewUseCase;
  final GetAllWordListsUseCase getAllWordListsUseCase;
  final GetWordsForListUseCase getWordsForListUseCase;

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

    // Batch fetch progress for all due words in a single query
    final wordIds = allDueWords.map((w) => w.id).toList();
    final progressResult = await getWordProgressBatchUseCase(
      GetWordProgressBatchParams(userId: userId, wordIds: wordIds),
    );
    final progressMap = progressResult.fold(
      (_) => <String, VocabularyProgress>{},
      (list) => {for (final p in list) p.wordId: p},
    );

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

  /// Loads ALL words in a specific unit for a "Cram/Review" session.
  /// Ignores SRS due dates and daily limits.
  Future<void> loadUnitReviewSession(String unitId) async {
    state = state.copyWith(isLoading: true);

    // 1. Get all word lists in this unit
    final allListsResult = await getAllWordListsUseCase(const GetAllWordListsParams());
    
    final unitListIds = allListsResult.fold(
      (f) => <String>[],
      (lists) => lists
          .where((l) => l.unitId == unitId)
          .map((l) => l.id)
          .toList(),
    );

    if (unitListIds.isEmpty) {
       state = state.copyWith(isLoading: false, words: []);
       return;
    }

    // 2. Get words for all these lists
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
    
    // Deduplicate by ID just in case
    final uniqueWords = {for (var w in allWords) w.id: w}.values.toList();

    // Shuffle for variety
    uniqueWords.shuffle();

    // Batch fetch progress for all words in a single query
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

    final isCorrect = response != SM2Response.dontKnow;
    final newCorrectCount = state.correctCount + (isCorrect ? 1 : 0);
    final newIncorrectCount = state.incorrectCount + (isCorrect ? 0 : 1);

    final wordId = currentWord.id;
    final timesRequeued = state.requeueCount[wordId] ?? 0;
    final isRequeued = timesRequeued > 0;

    // Re-queued word: skip DB write (first answer already saved).
    // Just advance and optionally re-queue again.
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

    // First time seeing this word: write to DB immediately.
    final newFirstCorrect = state.firstPassCorrectCount + (isCorrect ? 1 : 0);
    final newFirstIncorrect = state.firstPassIncorrectCount + (isCorrect ? 0 : 1);

    final currentProgress = state.progressMap[wordId];
    if (currentProgress != null) {
      final updatedProgress = SM2.calculateNextReview(
        currentProgress,
        response.toQuality(),
      );

      await updateWordProgressUseCase(
        UpdateWordProgressParams(progress: updatedProgress),
      );

      final newProgressMap = Map<String, VocabularyProgress>.from(state.progressMap);
      newProgressMap[wordId] = updatedProgress;

      // If Hard, re-queue for reinforcement (but SM-2 is already saved)
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
    } else {
      state = state.copyWith(
        correctCount: newCorrectCount,
        incorrectCount: newIncorrectCount,
        firstPassCorrectCount: newFirstCorrect,
        firstPassIncorrectCount: newFirstIncorrect,
        responses: [...state.responses, response],
        currentIndex: state.currentIndex + 1,
      );
    }
    _isProcessingAnswer = false;
  }

  /// Complete session and award XP (uses first-pass counts only)
  Future<DailyReviewResult?> completeSession() async {
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
      throw Exception('User not logged in');
    }

    return DailyReviewController(
      userId: userId,
      getDueForReviewUseCase: ref.watch(getDueForReviewUseCaseProvider),
      getWordProgressUseCase: ref.watch(getWordProgressUseCaseProvider),
      getWordProgressBatchUseCase: ref.watch(getWordProgressBatchUseCaseProvider),
      updateWordProgressUseCase: ref.watch(updateWordProgressUseCaseProvider),
      completeDailyReviewUseCase: ref.watch(completeDailyReviewUseCaseProvider),
      getAllWordListsUseCase: ref.watch(getAllWordListsUseCaseProvider),
      getWordsForListUseCase: ref.watch(getWordsForListUseCaseProvider),
    );
  },
);
