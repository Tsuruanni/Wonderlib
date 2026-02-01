import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/word_list.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

// ============================================
// VOCABULARY WORD PROVIDERS
// ============================================

/// Provides all vocabulary words with optional filters
final vocabularyWordsProvider =
    FutureProvider.family<List<VocabularyWord>, VocabularyFilters?>((ref, filters) async {
  final vocabRepo = ref.watch(vocabularyRepositoryProvider);
  final result = await vocabRepo.getAllWords(
    level: filters?.level,
    categories: filters?.categories,
    page: filters?.page ?? 1,
    pageSize: filters?.pageSize ?? 50,
  );
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides vocabulary search results
final vocabularySearchProvider =
    FutureProvider.family<List<VocabularyWord>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final vocabRepo = ref.watch(vocabularyRepositoryProvider);
  final result = await vocabRepo.searchWords(query);
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides words due for review
final dueForReviewProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final vocabRepo = ref.watch(vocabularyRepositoryProvider);
  final result = await vocabRepo.getDueForReview(userId);
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides new words to learn
final newWordsProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final vocabRepo = ref.watch(vocabularyRepositoryProvider);
  final result = await vocabRepo.getNewWords(userId: userId, limit: 10);
  return result.fold(
    (failure) => [],
    (words) => words,
  );
});

/// Provides vocabulary stats
final vocabularyStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final vocabRepo = ref.watch(vocabularyRepositoryProvider);
  final result = await vocabRepo.getVocabularyStats(userId);
  return result.fold(
    (failure) => {},
    (stats) => stats,
  );
});

/// Vocabulary filters
class VocabularyFilters {
  final String? level;
  final List<String>? categories;
  final int page;
  final int pageSize;

  const VocabularyFilters({
    this.level,
    this.categories,
    this.page = 1,
    this.pageSize = 50,
  });
}

// ============================================
// USER VOCABULARY PROVIDERS (using repository)
// ============================================

/// All vocabulary words (sync provider for UI)
final allVocabularyWordsProvider = FutureProvider<List<VocabularyWord>>((ref) async {
  final vocabRepo = ref.watch(vocabularyRepositoryProvider);
  final result = await vocabRepo.getAllWords();
  return result.fold((f) => [], (words) => words);
});

/// User's vocabulary progress
final userVocabularyProgressProvider = FutureProvider<List<VocabularyProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final vocabRepo = ref.watch(vocabularyRepositoryProvider);
  final result = await vocabRepo.getUserProgress(userId);
  return result.fold((f) => [], (progress) => progress);
});

/// User's learned words with progress (combined)
final userVocabularyProvider = FutureProvider<List<UserVocabularyItem>>((ref) async {
  final words = await ref.watch(allVocabularyWordsProvider.future);
  final progress = await ref.watch(userVocabularyProgressProvider.future);

  final progressMap = {for (var p in progress) p.wordId: p};

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

  int totalWords = items.length;
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
  final VocabularyWord word;
  final VocabularyProgress? progress;

  const UserVocabularyItem({required this.word, this.progress});

  VocabularyStatus get status => progress?.status ?? VocabularyStatus.newWord;
  bool get isMastered => progress?.isMastered ?? false;
}

/// Simple vocabulary stats
class VocabularyStats {
  final int totalWords;
  final int newCount;
  final int learningCount;
  final int reviewingCount;
  final int masteredCount;

  const VocabularyStats({
    required this.totalWords,
    required this.newCount,
    required this.learningCount,
    required this.reviewingCount,
    required this.masteredCount,
  });

  int get inProgressCount => learningCount + reviewingCount;
}

// ============================================
// VOCABULARY REVIEW CONTROLLER
// ============================================

/// Vocabulary review controller
class VocabularyReviewController extends StateNotifier<VocabularyReviewState> {
  final Ref _ref;

  VocabularyReviewController(this._ref)
      : super(const VocabularyReviewState());

  Future<void> loadReviewSession() async {
    state = state.copyWith(isLoading: true);

    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final vocabRepo = _ref.read(vocabularyRepositoryProvider);

    // Get due words and new words
    final dueResult = await vocabRepo.getDueForReview(userId);
    final newResult = await vocabRepo.getNewWords(userId: userId, limit: 5);

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

    final vocabRepo = _ref.read(vocabularyRepositoryProvider);

    // Get current progress
    final progressResult = await vocabRepo.getWordProgress(
      userId: userId,
      wordId: state.currentWord!.id,
    );

    final progress = progressResult.fold((f) => null, (p) => p);
    if (progress == null) return;

    // Calculate next review
    final updatedProgress = progress.calculateNextReview(quality);
    await vocabRepo.updateWordProgress(updatedProgress);

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
  final bool isLoading;
  final List<VocabularyWord> words;
  final int currentIndex;
  final int correctCount;
  final int incorrectCount;

  const VocabularyReviewState({
    this.isLoading = false,
    this.words = const [],
    this.currentIndex = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
  });

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
// WORD LIST PROVIDERS (using repository)
// ============================================

/// All word lists
final allWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getAllWordLists();
  return result.fold((f) => [], (lists) => lists);
});

/// System word lists (admin-created)
final systemWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getAllWordLists(isSystem: true);
  return result.fold((f) => [], (lists) => lists);
});

/// Story vocabulary lists (from books user has read)
final storyWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getAllWordLists(category: WordListCategory.storyVocab);
  return result.fold((f) => [], (lists) => lists);
});

/// Word lists by category
final wordListsByCategoryProvider = FutureProvider.family<List<WordList>, WordListCategory>((ref, category) async {
  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getAllWordLists(category: category);
  return result.fold((f) => [], (lists) => lists);
});

/// Single word list by ID
final wordListByIdProvider = FutureProvider.family<WordList?, String>((ref, id) async {
  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getWordListById(id);
  return result.fold((f) => null, (list) => list);
});

/// Words for a specific list
final wordsForListProvider = FutureProvider.family<List<VocabularyWord>, String>((ref, listId) async {
  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getWordsForList(listId);
  return result.fold((f) => [], (words) => words);
});

/// User's progress for all word lists
final userWordListProgressProvider = FutureProvider<List<UserWordListProgress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getUserWordListProgress(userId);
  return result.fold((f) => [], (progress) => progress);
});

/// User's progress for a specific word list
final progressForListProvider = FutureProvider.family<UserWordListProgress?, String>((ref, listId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final repo = ref.watch(wordListRepositoryProvider);
  final result = await repo.getProgressForList(userId: userId, listId: listId);
  return result.fold((f) => null, (progress) => progress);
});

/// Word lists with progress (for display in hub)
final wordListsWithProgressProvider = FutureProvider<List<WordListWithProgress>>((ref) async {
  final lists = await ref.watch(allWordListsProvider.future);
  final progressList = await ref.watch(userWordListProgressProvider.future);

  final progressMap = {for (var p in progressList) p.wordListId: p};

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
        .compareTo(a.progress?.updatedAt ?? DateTime(0)));
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
  final WordList wordList;
  final UserWordListProgress? progress;

  const WordListWithProgress({
    required this.wordList,
    this.progress,
  });

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
  final int totalWords;
  final int masteredWords;
  final int dueForReview;
  final int completedLists;

  const VocabularyHubStats({
    required this.totalWords,
    required this.masteredWords,
    required this.dueForReview,
    required this.completedLists,
  });
}

// ============================================
// WORD LIST PROGRESS CONTROLLER
// ============================================

/// Controller for managing word list progress state
class WordListProgressController extends StateNotifier<Map<String, UserWordListProgress>> {
  final Ref _ref;

  WordListProgressController(this._ref) : super({}) {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final repo = _ref.read(wordListRepositoryProvider);
    final result = await repo.getUserWordListProgress(userId);
    result.fold(
      (f) => null,
      (progress) {
        state = {for (var p in progress) p.wordListId: p};
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
    final repo = _ref.read(wordListRepositoryProvider);

    final result = await repo.completePhase(
      userId: userId,
      listId: listId,
      phase: phase,
      score: score,
      total: total,
    );

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
    final repo = _ref.read(wordListRepositoryProvider);

    await repo.resetProgress(userId: userId, listId: listId);

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
