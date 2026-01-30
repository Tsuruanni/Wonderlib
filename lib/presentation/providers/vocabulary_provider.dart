import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/sm2_algorithm.dart';
import '../../data/datasources/local/mock_data.dart';
import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/word_list.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

// ============================================
// MOCK-BASED PROVIDERS (for development)
// ============================================

/// All vocabulary words from mock data
final mockVocabularyWordsProvider = Provider<List<VocabularyWord>>((ref) {
  return MockData.vocabularyWords;
});

/// Vocabulary progress from mock data
final mockVocabularyProgressProvider = Provider<List<VocabularyProgress>>((ref) {
  return MockData.vocabularyProgress;
});

/// User's learned words with progress
final userVocabularyProvider = Provider<List<UserVocabularyItem>>((ref) {
  final words = ref.watch(mockVocabularyWordsProvider);
  final progress = ref.watch(mockVocabularyProgressProvider);

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
final wordsDueForReviewProvider = Provider<List<UserVocabularyItem>>((ref) {
  final items = ref.watch(userVocabularyProvider);
  return items.where((item) {
    if (item.progress == null) return false;
    return item.progress!.isDueForReview;
  }).toList();
});

/// New words (not started yet)
final newWordsToLearnProvider = Provider<List<UserVocabularyItem>>((ref) {
  final items = ref.watch(userVocabularyProvider);
  return items.where((item) => item.progress == null || item.progress!.isNew).toList();
});

/// Vocabulary stats
final vocabularyStatsSimpleProvider = Provider<VocabularyStats>((ref) {
  final items = ref.watch(userVocabularyProvider);

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
    StateNotifierProvider<VocabularyReviewController, VocabularyReviewState>((ref) {
  return VocabularyReviewController(ref);
});

// ============================================
// WORD LIST PROVIDERS
// ============================================

/// All word lists from mock data
final allWordListsProvider = Provider<List<WordList>>((ref) {
  return MockData.wordLists;
});

/// System word lists (admin-created)
final systemWordListsProvider = Provider<List<WordList>>((ref) {
  final lists = ref.watch(allWordListsProvider);
  return lists.where((l) => l.isSystem).toList();
});

/// Story vocabulary lists (from books user has read)
final storyWordListsProvider = Provider<List<WordList>>((ref) {
  final lists = ref.watch(allWordListsProvider);
  return lists.where((l) => l.category == WordListCategory.storyVocab).toList();
});

/// Word lists by category
final wordListsByCategoryProvider = Provider.family<List<WordList>, WordListCategory>((ref, category) {
  final lists = ref.watch(allWordListsProvider);
  return lists.where((l) => l.category == category).toList();
});

/// Single word list by ID
final wordListByIdProvider = Provider.family<WordList?, String>((ref, id) {
  final lists = ref.watch(allWordListsProvider);
  try {
    return lists.firstWhere((l) => l.id == id);
  } catch (_) {
    return null;
  }
});

/// Words for a specific list
final wordsForListProvider = Provider.family<List<VocabularyWord>, String>((ref, listId) {
  return MockData.getWordsForList(listId);
});

/// User's progress for all word lists
final userWordListProgressProvider = Provider<List<UserWordListProgress>>((ref) {
  return MockData.userWordListProgress;
});

/// User's progress for a specific word list
final progressForListProvider = Provider.family<UserWordListProgress?, String>((ref, listId) {
  final progressList = ref.watch(userWordListProgressProvider);
  try {
    return progressList.firstWhere((p) => p.wordListId == listId);
  } catch (_) {
    return null;
  }
});

/// Word lists with progress (for display in hub)
final wordListsWithProgressProvider = Provider<List<WordListWithProgress>>((ref) {
  final lists = ref.watch(allWordListsProvider);
  final progressList = ref.watch(userWordListProgressProvider);

  final progressMap = {for (var p in progressList) p.wordListId: p};

  return lists.map((list) {
    return WordListWithProgress(
      wordList: list,
      progress: progressMap[list.id],
    );
  }).toList();
});

/// Word lists user has started (for "Continue Learning" section)
final continueWordListsProvider = Provider<List<WordListWithProgress>>((ref) {
  final listsWithProgress = ref.watch(wordListsWithProgressProvider);
  return listsWithProgress
      .where((lwp) => lwp.progress != null && !lwp.progress!.isFullyComplete)
      .toList()
    ..sort((a, b) => (b.progress?.updatedAt ?? DateTime(0))
        .compareTo(a.progress?.updatedAt ?? DateTime(0)));
});

/// Recommended word lists (system lists user hasn't started)
final recommendedWordListsProvider = Provider<List<WordListWithProgress>>((ref) {
  final listsWithProgress = ref.watch(wordListsWithProgressProvider);
  return listsWithProgress
      .where((lwp) => lwp.wordList.isSystem && lwp.progress == null)
      .toList();
});

/// Total words due for review across all lists (SM-2)
final totalDueWordsCountProvider = Provider<int>((ref) {
  final dueWords = ref.watch(wordsDueForReviewProvider);
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
final vocabularyHubStatsProvider = Provider<VocabularyHubStats>((ref) {
  final allWords = ref.watch(userVocabularyProvider);
  final dueCount = ref.watch(totalDueWordsCountProvider);
  final listsWithProgress = ref.watch(wordListsWithProgressProvider);

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
