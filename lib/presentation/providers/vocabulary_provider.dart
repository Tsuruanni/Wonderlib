import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/word_list.dart';
import '../../domain/usecases/vocabulary/get_all_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_new_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_user_vocabulary_progress_usecase.dart';
import '../../domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/search_words_usecase.dart';
import '../../domain/usecases/vocabulary/update_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_learned_today_usecase.dart';
import '../../domain/usecases/wordlist/complete_phase_usecase.dart';
import '../../domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import '../../domain/usecases/wordlist/get_progress_for_list_usecase.dart';
import '../../domain/usecases/wordlist/get_user_word_list_progress_usecase.dart';
import '../../domain/usecases/wordlist/get_word_list_by_id_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
import '../../domain/usecases/wordlist/reset_progress_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

// ============================================
// VOCABULARY WORD PROVIDERS
// ============================================

/// Provides all vocabulary words with optional filters
final vocabularyWordsProvider =
    FutureProvider.family<List<VocabularyWord>, VocabularyFilters?>((ref, filters) async {
  final useCase = ref.watch(getAllWordsUseCaseProvider);
  final result = await useCase(GetAllWordsParams(
    level: filters?.level,
    categories: filters?.categories,
    page: filters?.page ?? 1,
    pageSize: filters?.pageSize ?? 50,
  ),);
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides vocabulary search results
final vocabularySearchProvider =
    FutureProvider.family<List<VocabularyWord>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final useCase = ref.watch(searchWordsUseCaseProvider);
  final result = await useCase(SearchWordsParams(query: query));
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides words due for review
final dueForReviewProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getDueForReviewUseCaseProvider);
  final result = await useCase(GetDueForReviewParams(userId: userId));
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides new words to learn
final newWordsProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getNewWordsUseCaseProvider);
  final result = await useCase(GetNewWordsParams(userId: userId, limit: 10));
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides vocabulary stats
final vocabularyStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final useCase = ref.watch(getVocabularyStatsUseCaseProvider);
  final result = await useCase(GetVocabularyStatsParams(userId: userId));
  return result.fold(
    (failure) => {},
    (stats) => stats,
  );
});

/// Vocabulary filters
class VocabularyFilters {

  const VocabularyFilters({
    this.level,
    this.categories,
    this.page = 1,
    this.pageSize = 50,
  });
  final String? level;
  final List<String>? categories;
  final int page;
  final int pageSize;
}

// ============================================
// USER VOCABULARY PROVIDERS (using UseCases)
// ============================================

/// All vocabulary words (sync provider for UI)
final allVocabularyWordsProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final useCase = ref.watch(getAllWordsUseCaseProvider);
  final result = await useCase(const GetAllWordsParams());
  return result.fold((f) => [], (words) => words);
});

/// User's vocabulary progress
final userVocabularyProgressProvider = FutureProvider<List<VocabularyProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getUserVocabularyProgressUseCaseProvider);
  final result = await useCase(GetUserVocabularyProgressParams(userId: userId));
  return result.fold((f) => [], (progress) => progress);
});

/// User's learned words with progress (combined)
final userVocabularyProvider = FutureProvider<List<UserVocabularyItem>>((ref) async {
  final words = await ref.watch(allVocabularyWordsProvider.future);
  final progress = await ref.watch(userVocabularyProgressProvider.future);

  final progressMap = {for (final p in progress) p.wordId: p};

  return words.map((word) {
    final wordProgress = progressMap[word.id];
    return UserVocabularyItem(
      word: word,
      progress: wordProgress,
    );
  }).toList();
});

/// Words due for review today
final wordsDueForReviewProvider = FutureProvider<List<UserVocabularyItem>>((ref) async {
  final items = await ref.watch(userVocabularyProvider.future);
  return items.where((item) {
    if (item.progress == null) return false;
    return item.progress!.isDueForReview;
  }).toList();
});

/// New words (not started yet)
final newWordsToLearnProvider = FutureProvider<List<UserVocabularyItem>>((ref) async {
  final items = await ref.watch(userVocabularyProvider.future);
  return items.where((item) => item.progress == null || item.progress!.isNew).toList();
});

/// Vocabulary stats (simple)
final vocabularyStatsSimpleProvider = FutureProvider<VocabularyStats>((ref) async {
  final items = await ref.watch(userVocabularyProvider.future);

  final int totalWords = items.length;
  int newCount = 0;
  int learningCount = 0;
  int reviewingCount = 0;
  int masteredCount = 0;

  for (final item in items) {
    if (item.progress == null) {
      newCount++;
    } else {
      switch (item.progress!.status) {
        case VocabularyStatus.newWord:
          newCount++;
        case VocabularyStatus.learning:
          learningCount++;
        case VocabularyStatus.reviewing:
          reviewingCount++;
        case VocabularyStatus.mastered:
          masteredCount++;
      }
    }
  }

  return VocabularyStats(
    totalWords: totalWords,
    newCount: newCount,
    learningCount: learningCount,
    reviewingCount: reviewingCount,
    masteredCount: masteredCount,
  );
});

/// User vocabulary item combining word and progress
class UserVocabularyItem {

  const UserVocabularyItem({required this.word, this.progress});
  final VocabularyWord word;
  final VocabularyProgress? progress;

  VocabularyStatus get status => progress?.status ?? VocabularyStatus.newWord;
  bool get isMastered => progress?.isMastered ?? false;
}

/// Simple vocabulary stats
class VocabularyStats {

  const VocabularyStats({
    required this.totalWords,
    required this.newCount,
    required this.learningCount,
    required this.reviewingCount,
    required this.masteredCount,
  });
  final int totalWords;
  final int newCount;
  final int learningCount;
  final int reviewingCount;
  final int masteredCount;

  int get inProgressCount => learningCount + reviewingCount;
}

// ============================================
// VOCABULARY REVIEW CONTROLLER
// ============================================

/// Vocabulary review controller
class VocabularyReviewController extends StateNotifier<VocabularyReviewState> {

  VocabularyReviewController(this._ref)
      : super(const VocabularyReviewState());
  final Ref _ref;

  Future<void> loadReviewSession() async {
    state = state.copyWith(isLoading: true);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final dueUseCase = _ref.read(getDueForReviewUseCaseProvider);
    final newUseCase = _ref.read(getNewWordsUseCaseProvider);

    // Get due words and new words
    final dueResult = await dueUseCase(GetDueForReviewParams(userId: userId));
    final newResult = await newUseCase(GetNewWordsParams(userId: userId, limit: 5));

    final dueWords = dueResult.fold((f) => <VocabularyWord>[], (w) => w);
    final newWords = newResult.fold((f) => <VocabularyWord>[], (w) => w);

    final allWords = [...dueWords, ...newWords];

    state = state.copyWith(
      isLoading: false,
      words: allWords,
      currentIndex: 0,
      correctCount: 0,
      incorrectCount: 0,
    );
  }

  Future<void> answerWord(int quality) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null || state.currentWord == null) return;

    final getProgressUseCase = _ref.read(getWordProgressUseCaseProvider);
    final updateProgressUseCase = _ref.read(updateWordProgressUseCaseProvider);

    // Get current progress
    final progressResult = await getProgressUseCase(GetWordProgressParams(
      userId: userId,
      wordId: state.currentWord!.id,
    ),);

    final progress = progressResult.fold((f) => null, (p) => p);
    if (progress == null) return;

    // Calculate next review
    final updatedProgress = progress.calculateNextReview(quality);
    await updateProgressUseCase(UpdateWordProgressParams(progress: updatedProgress));

    // Update state
    state = state.copyWith(
      correctCount: quality >= 3 ? state.correctCount + 1 : state.correctCount,
      incorrectCount: quality < 3 ? state.incorrectCount + 1 : state.incorrectCount,
      currentIndex: state.currentIndex + 1,
    );
  }

  void reset() {
    state = const VocabularyReviewState();
  }
}

class VocabularyReviewState {

  const VocabularyReviewState({
    this.isLoading = false,
    this.words = const [],
    this.currentIndex = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
  });
  final bool isLoading;
  final List<VocabularyWord> words;
  final int currentIndex;
  final int correctCount;
  final int incorrectCount;

  VocabularyWord? get currentWord =>
      currentIndex < words.length ? words[currentIndex] : null;

  bool get isComplete => currentIndex >= words.length && words.isNotEmpty;

  double get accuracy =>
      (correctCount + incorrectCount) > 0
          ? correctCount / (correctCount + incorrectCount)
          : 0;

  VocabularyReviewState copyWith({
    bool? isLoading,
    List<VocabularyWord>? words,
    int? currentIndex,
    int? correctCount,
    int? incorrectCount,
  }) {
    return VocabularyReviewState(
      isLoading: isLoading ?? this.isLoading,
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
    );
  }
}

final vocabularyReviewControllerProvider =
    StateNotifierProvider.autoDispose<VocabularyReviewController, VocabularyReviewState>((ref) {
  return VocabularyReviewController(ref);
});

// ============================================
// WORD LIST PROVIDERS (using UseCases)
// ============================================

/// All word lists
final allWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final useCase = ref.watch(getAllWordListsUseCaseProvider);
  final result = await useCase(const GetAllWordListsParams());
  return result.fold((f) => [], (lists) => lists);
});

/// System word lists (admin-created)
final systemWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final useCase = ref.watch(getAllWordListsUseCaseProvider);
  final result = await useCase(const GetAllWordListsParams(isSystem: true));
  return result.fold((f) => [], (lists) => lists);
});

/// Story vocabulary lists (from books user has read)
final storyWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final useCase = ref.watch(getAllWordListsUseCaseProvider);
  final result = await useCase(const GetAllWordListsParams(category: WordListCategory.storyVocab));
  return result.fold((f) => [], (lists) => lists);
});

/// Word lists by category
final wordListsByCategoryProvider = FutureProvider.family<List<WordList>, WordListCategory>((ref, category) async {
  final useCase = ref.watch(getAllWordListsUseCaseProvider);
  final result = await useCase(GetAllWordListsParams(category: category));
  return result.fold((f) => [], (lists) => lists);
});

/// Single word list by ID
final wordListByIdProvider = FutureProvider.family<WordList?, String>((ref, id) async {
  final useCase = ref.watch(getWordListByIdUseCaseProvider);
  final result = await useCase(GetWordListByIdParams(listId: id));
  return result.fold((f) => null, (list) => list);
});

/// Words for a specific list
final wordsForListProvider = FutureProvider.family<List<VocabularyWord>, String>((ref, listId) async {
  final useCase = ref.watch(getWordsForListUseCaseProvider);
  final result = await useCase(GetWordsForListParams(listId: listId));
  return result.fold((f) => [], (words) => words);
});

/// User's progress for all word lists
final userWordListProgressProvider = FutureProvider<List<UserWordListProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getUserWordListProgressUseCaseProvider);
  final result = await useCase(GetUserWordListProgressParams(userId: userId));
  return result.fold((f) => [], (progress) => progress);
});

/// User's progress for a specific word list
final progressForListProvider = FutureProvider.family<UserWordListProgress?, String>((ref, listId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getProgressForListUseCaseProvider);
  final result = await useCase(GetProgressForListParams(userId: userId, listId: listId));
  return result.fold((f) => null, (progress) => progress);
});

/// Word lists with progress (for display in hub)
final wordListsWithProgressProvider = FutureProvider<List<WordListWithProgress>>((ref) async {
  final lists = await ref.watch(allWordListsProvider.future);
  final progressList = await ref.watch(userWordListProgressProvider.future);

  final progressMap = {for (final p in progressList) p.wordListId: p};

  return lists.map((list) {
    return WordListWithProgress(
      wordList: list,
      progress: progressMap[list.id],
    );
  }).toList();
});

/// Word lists user has started (for "Continue Learning" section)
final continueWordListsProvider = FutureProvider<List<WordListWithProgress>>((ref) async {
  final listsWithProgress = await ref.watch(wordListsWithProgressProvider.future);
  final filtered = listsWithProgress
      .where((lwp) => lwp.progress != null && !lwp.progress!.isFullyComplete)
      .toList()
    ..sort((a, b) => (b.progress?.updatedAt ?? DateTime(0))
        .compareTo(a.progress?.updatedAt ?? DateTime(0)),);
  return filtered;
});

/// Recommended word lists (system lists user hasn't started)
final recommendedWordListsProvider = FutureProvider<List<WordListWithProgress>>((ref) async {
  final listsWithProgress = await ref.watch(wordListsWithProgressProvider.future);
  return listsWithProgress
      .where((lwp) => lwp.wordList.isSystem && lwp.progress == null)
      .toList();
});

/// Total words due for review across all lists (SM-2)
final totalDueWordsCountProvider = FutureProvider<int>((ref) async {
  final dueWords = await ref.watch(wordsDueForReviewProvider.future);
  return dueWords.length;
});

/// Combined class for word list with its progress
class WordListWithProgress {

  const WordListWithProgress({
    required this.wordList,
    this.progress,
  });
  final WordList wordList;
  final UserWordListProgress? progress;

  double get progressPercentage => progress?.progressPercentage ?? 0.0;
  bool get isStarted => progress != null;
  bool get isComplete => progress?.isFullyComplete ?? false;
  int? get nextPhase => progress?.nextPhase;
}

/// Vocabulary hub stats
final vocabularyHubStatsProvider = FutureProvider<VocabularyHubStats>((ref) async {
  final allWords = await ref.watch(userVocabularyProvider.future);
  final dueCount = await ref.watch(totalDueWordsCountProvider.future);
  final listsWithProgress = await ref.watch(wordListsWithProgressProvider.future);

  final masteredCount = allWords.where((w) => w.isMastered).length;
  final completedLists = listsWithProgress.where((l) => l.isComplete).length;

  return VocabularyHubStats(
    totalWords: allWords.length,
    masteredWords: masteredCount,
    dueForReview: dueCount,
    completedLists: completedLists,
  );
});

class VocabularyHubStats {

  const VocabularyHubStats({
    required this.totalWords,
    required this.masteredWords,
    required this.dueForReview,
    required this.completedLists,
  });
  final int totalWords;
  final int masteredWords;
  final int dueForReview;
  final int completedLists;
}

// ============================================
// WORD LIST PROGRESS CONTROLLER
// ============================================

/// Controller for managing word list progress state
class WordListProgressController extends StateNotifier<Map<String, UserWordListProgress>> {

  WordListProgressController(this._ref) : super({}) {
    _loadProgress();
  }
  final Ref _ref;

  Future<void> _loadProgress() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final useCase = _ref.read(getUserWordListProgressUseCaseProvider);
    final result = await useCase(GetUserWordListProgressParams(userId: userId));
    result.fold(
      (f) => null,
      (progress) {
        state = {for (final p in progress) p.wordListId: p};
      },
    );
  }

  /// Get progress for a specific list
  UserWordListProgress? getProgress(String listId) {
    return state[listId];
  }

  /// Complete a phase for a word list
  Future<void> completePhase(String listId, int phase, {int? score, int? total}) async {
    final userId = _ref.read(currentUserIdProvider) ?? 'user-1';
    final useCase = _ref.read(completePhaseUseCaseProvider);

    final result = await useCase(CompletePhaseParams(
      userId: userId,
      listId: listId,
      phase: phase,
      score: score,
      total: total,
    ),);

    result.fold(
      (f) => null,
      (updated) {
        state = {...state, listId: updated};
      },
    );
  }

  /// Reset progress for a word list
  Future<void> resetProgress(String listId) async {
    final userId = _ref.read(currentUserIdProvider) ?? 'user-1';
    final useCase = _ref.read(resetProgressUseCaseProvider);

    await useCase(ResetProgressParams(userId: userId, listId: listId));

    final newState = Map<String, UserWordListProgress>.from(state);
    newState.remove(listId);
    state = newState;
  }
}

final wordListProgressControllerProvider =
    StateNotifierProvider.autoDispose<WordListProgressController, Map<String, UserWordListProgress>>((ref) {
  return WordListProgressController(ref);
});

/// Get progress for a specific list (reactive)
final wordListProgressProvider = Provider.family<UserWordListProgress?, String>((ref, listId) {
  final progressMap = ref.watch(wordListProgressControllerProvider);
  return progressMap[listId];
});

/// Words learned today count (for daily task)
final wordsLearnedTodayProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;

  final useCase = ref.watch(getWordsLearnedTodayUseCaseProvider);
  final result = await useCase(GetWordsLearnedTodayParams(userId: userId));
  return result.fold(
    (failure) => 0,
    (count) => count,
  );
});

// ============================================
// VOCABULARY ACTIONS
// ============================================

/// Result type for vocabulary actions
class VocabularyActionResult {
  const VocabularyActionResult({required this.success, this.errorMessage});
  final bool success;
  final String? errorMessage;
}

/// Add a word to user's vocabulary
Future<VocabularyActionResult> addWordToVocabulary(WidgetRef ref, String wordId) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    return const VocabularyActionResult(
      success: false,
      errorMessage: 'User not logged in',
    );
  }

  final useCase = ref.read(addWordToVocabularyUseCaseProvider);
  final result = await useCase(
    AddWordToVocabularyParams(userId: userId, wordId: wordId),
  );

  return result.fold(
    (failure) => VocabularyActionResult(
      success: false,
      errorMessage: failure.message,
    ),
    (_) => const VocabularyActionResult(success: true),
  );
}
