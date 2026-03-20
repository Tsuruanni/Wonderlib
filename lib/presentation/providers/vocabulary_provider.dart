import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../domain/entities/book.dart';
import '../../domain/entities/learning_path.dart';
import 'book_provider.dart';
import 'daily_review_provider.dart';
import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/vocabulary_unit.dart';
import '../../domain/entities/word_list.dart';
import '../../domain/usecases/vocabulary/complete_node_usecase.dart';
import '../../domain/usecases/wordlist/get_user_learning_paths_usecase.dart';
import '../../domain/usecases/vocabulary/get_node_completions_usecase.dart';
import '../../domain/usecases/vocabulary/get_all_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_due_for_review_usecase.dart';
import '../../domain/usecases/vocabulary/get_new_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_user_vocabulary_progress_usecase.dart';
import '../../domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_by_id_usecase.dart';
import '../../domain/usecases/vocabulary/get_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/search_words_usecase.dart';
import '../../domain/usecases/vocabulary/update_word_progress_usecase.dart';
import '../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_from_lists_learned_today_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_learned_today_usecase.dart';
import '../../domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import '../../domain/usecases/wordlist/get_progress_for_list_usecase.dart';
import '../../domain/usecases/wordlist/get_user_word_list_progress_usecase.dart';
import '../../domain/usecases/wordlist/get_word_list_by_id_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
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

/// User's learned words (starts from progress, loads word details)
/// Unlike userVocabularyProvider which starts from all words (paginated),
/// this starts from user's progress entries so it shows ALL learned words.
final learnedWordsWithDetailsProvider = FutureProvider<List<UserVocabularyItem>>((ref) async {
  final progressList = await ref.watch(userVocabularyProgressProvider.future);
  if (progressList.isEmpty) return [];

  final getWordUseCase = ref.watch(getWordByIdUseCaseProvider);
  final items = <UserVocabularyItem>[];

  for (final progress in progressList) {
    final result = await getWordUseCase(
      GetWordByIdParams(wordId: progress.wordId),
    );
    result.fold(
      (_) {}, // skip words not found in vocabulary_words table
      (word) => items.add(UserVocabularyItem(word: word, progress: progress)),
    );
  }

  return items;
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
      .where((lwp) => lwp.progress != null && !lwp.progress!.isComplete)
      .toList()
    ..sort((a, b) => (b.progress?.lastSessionAt ?? DateTime(0))
        .compareTo(a.progress?.lastSessionAt ?? DateTime(0)),);
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
  bool get isComplete => progress?.isComplete ?? false;
  int get starCount => progress?.starCount ?? 0;
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
// LEARNING PATH PROVIDERS
// ============================================

/// Sealed hierarchy for items in a learning path unit.
/// Each item is either a word list or a book, with a sort order for interleaving.
sealed class PathItemData {
  const PathItemData({required this.sortOrder});
  final int sortOrder;
  bool get isComplete;
}

class PathWordListItem extends PathItemData {
  const PathWordListItem({
    required super.sortOrder,
    required this.wordListWithProgress,
  });
  final WordListWithProgress wordListWithProgress;

  @override
  bool get isComplete => wordListWithProgress.isComplete;
}

class PathBookItem extends PathItemData {
  const PathBookItem({
    required super.sortOrder,
    required this.bookWithProgress,
  });
  final UnitBookWithProgress bookWithProgress;

  @override
  bool get isComplete => bookWithProgress.isCompleted;
}

class PathGameItem extends PathItemData {
  const PathGameItem({required super.sortOrder, required this.isCompleted});
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}

class PathTreasureItem extends PathItemData {
  const PathTreasureItem({required super.sortOrder, required this.isCompleted});
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}

class PathDailyReviewItem extends PathItemData {
  const PathDailyReviewItem({
    required super.sortOrder,
    required this.completedAt,
    required this.isCompleted,
  });
  final DateTime? completedAt;
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}

/// Node types for special path nodes (flipbook removed — replaced by book nodes)
const allSpecialNodeTypes = ['daily_review', 'game', 'treasure'];

/// A book assigned to a unit with its reading completion status.
class UnitBookWithProgress {
  const UnitBookWithProgress({
    required this.bookId,
    required this.book,
    required this.isCompleted,
    required this.sortOrder,
  });

  final String bookId;
  final Book book;
  final bool isCompleted;
  final int sortOrder;
}

/// One unit in the learning path (header + unified items list)
class PathUnitData {
  const PathUnitData({
    required this.unit,
    required this.items,
    required this.completedNodeTypes,
    required this.sequentialLock,
    required this.booksExemptFromLock,
  });

  final VocabularyUnit unit;
  final List<PathItemData> items;
  final Set<String> completedNodeTypes;
  final bool sequentialLock;
  final bool booksExemptFromLock;

  /// Whether every required item is complete.
  /// Books exempt from lock are excluded from the "required" check.
  /// Daily review is a daily gate, not a progression requirement — excluded.
  bool get isAllComplete {
    final requiredItems = items.where((i) {
      if (i is PathBookItem && booksExemptFromLock) return false;
      if (i is PathDailyReviewItem) return false; // DR is a daily gate, not a progression requirement
      return true;
    });
    return requiredItems.every((i) => i.isComplete);
  }
}

/// Calculate lock state for each item in a unit.
///
/// When [sequentialLock] is true, each non-exempt item is locked until
/// the previous non-exempt item is complete.
/// Books are exempt from sequential lock when [booksExemptFromLock] is true.
/// If [isUnitLocked] is true, all items are locked.
List<bool> calculateLocks({
  required List<PathItemData> items,
  required bool sequentialLock,
  required bool booksExemptFromLock,
  required bool isUnitLocked,
}) {
  if (isUnitLocked) return List.filled(items.length, true);
  if (!sequentialLock) return List.filled(items.length, false);

  final locks = List.filled(items.length, false);
  bool previousNonExemptCompleted = true;

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final isExemptBook = item is PathBookItem && booksExemptFromLock;

    if (isExemptBook) {
      locks[i] = false;
    } else {
      locks[i] = !previousNonExemptCompleted;
      if (!locks[i]) {
        previousNonExemptCompleted = item.isComplete;
      }
    }
  }
  return locks;
}

/// Fetches all learning paths for the current user.
/// Replaces the old vocabularyUnitsProvider + unitBooksProvider combination.
/// Returns hierarchical data: learning paths → units → items (word lists + books, interleaved by sort_order).
final userLearningPathsProvider = FutureProvider<List<LearningPath>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  final useCase = ref.watch(getUserLearningPathsUseCaseProvider);
  final result = await useCase(GetUserLearningPathsParams(userId: user.id));
  return result.fold((_) => [], (paths) => paths);
});

/// Node completions for the current user (Set of "unitId:nodeType" for fast lookup)
final nodeCompletionsProvider = FutureProvider<Map<String, Set<String>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final useCase = ref.watch(getNodeCompletionsUseCaseProvider);
  final result = await useCase(GetNodeCompletionsParams(userId: userId));

  return result.fold(
    (failure) => {},
    (completions) {
      // Group by unitId → Set<nodeType>
      final map = <String, Set<String>>{};
      for (final c in completions) {
        map.putIfAbsent(c.unitId, () => {}).add(c.nodeType);
      }
      return map;
    },
  );
});

/// Complete learning path: units + unified items list + progress + node completions.
///
/// Data flow:
/// 1. userLearningPathsProvider → gives us learning paths → units → items (IDs + types + sort_order)
/// 2. For word list items: match with allWordListsProvider data + userWordListProgressProvider
/// 3. For book items: fetch book details via bookByIdProvider + completedBookIdsProvider
/// 4. Build PathUnitData with a single unified items list (PathItemData sealed hierarchy)
///
/// Items are ordered by sort_order from the RPC. Word lists and books are interleaved
/// in a single list for correct rendering order.
final learningPathProvider = FutureProvider<List<PathUnitData>>((ref) async {
  final learningPaths = await ref.watch(userLearningPathsProvider.future);
  final allLists = await ref.watch(allWordListsProvider.future);
  final progressList = await ref.watch(userWordListProgressProvider.future);
  final nodeCompletions = await ref.watch(nodeCompletionsProvider.future);
  final completedBookIds = await ref.watch(completedBookIdsProvider.future);

  if (learningPaths.isEmpty) return [];

  // Build lookup maps
  final progressMap = {for (final p in progressList) p.wordListId: p};
  final wordListMap = {for (final wl in allLists) wl.id: wl};

  final result = <PathUnitData>[];

  for (final path in learningPaths) {
    for (final lpUnit in path.units) {
      if (lpUnit.items.isEmpty) continue;

      // Create a VocabularyUnit from LearningPathUnit data
      // (widgets like PathUnitBanner expect VocabularyUnit)
      final vocabUnit = VocabularyUnit(
        id: lpUnit.unitId,
        name: lpUnit.unitName,
        sortOrder: lpUnit.sortOrder,
        color: lpUnit.unitColor,
        icon: lpUnit.unitIcon,
        createdAt: DateTime.now(), // not available from RPC, not used by widgets
        updatedAt: DateTime.now(),
      );

      // Build unified items list (word lists, books, game, treasure interleaved by sort_order)
      final items = <PathItemData>[];
      for (final item in lpUnit.items) {
        if (item.itemType == LearningPathItemType.wordList) {
          final wordList = wordListMap[item.itemId];
          if (wordList == null) continue;
          items.add(
            PathWordListItem(
              sortOrder: item.sortOrder,
              wordListWithProgress: WordListWithProgress(
                wordList: wordList,
                progress: progressMap[item.itemId],
              ),
            ),
          );
        } else if (item.itemType == LearningPathItemType.book) {
          final book = await ref.watch(bookByIdProvider(item.itemId).future);
          if (book != null) {
            items.add(
              PathBookItem(
                sortOrder: item.sortOrder,
                bookWithProgress: UnitBookWithProgress(
                  bookId: item.itemId,
                  book: book,
                  isCompleted: completedBookIds.contains(item.itemId),
                  sortOrder: item.sortOrder,
                ),
              ),
            );
          }
        } else if (item.itemType == LearningPathItemType.game) {
          final isCompleted = nodeCompletions[lpUnit.unitId]?.contains('game') ?? false;
          items.add(PathGameItem(
            sortOrder: item.sortOrder,
            isCompleted: isCompleted,
          ),);
        } else if (item.itemType == LearningPathItemType.treasure) {
          final isCompleted = nodeCompletions[lpUnit.unitId]?.contains('treasure') ?? false;
          items.add(PathTreasureItem(
            sortOrder: item.sortOrder,
            isCompleted: isCompleted,
          ),);
        }
      }

      // --- Daily Review injection ---
      // Uses existing todayReviewSessionProvider (reads daily_review_sessions table)
      // No new tables or RPCs needed.
      final todaySession = await ref.watch(todayReviewSessionProvider.future);
      final dailyReviewDueCount = await ref
          .watch(totalDueWordsForReviewProvider.future)
          .catchError((_) => 0);
      final drDoneToday = todaySession != null;
      final drNeeded = dailyReviewDueCount >= minDailyReviewCount;

      // Show DR node if needed OR if already done today (so student sees the completed node)
      if (drNeeded || drDoneToday) {
        // Position: just before the first incomplete non-exempt item
        int drSortOrder = items.isEmpty ? 0 : items.last.sortOrder + 1;
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final isExempt = item is PathBookItem && path.booksExemptFromLock;
          if (!isExempt && !item.isComplete) {
            drSortOrder = item.sortOrder;
            break;
          }
        }

        items.add(PathDailyReviewItem(
          sortOrder: drSortOrder,
          completedAt: drDoneToday ? DateTime.now() : null,
          isCompleted: drDoneToday,
        ));
      }

      // Re-sort: DR items come before other items with the same sortOrder
      items.sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        if (a is PathDailyReviewItem && b is! PathDailyReviewItem) return -1;
        if (b is PathDailyReviewItem && a is! PathDailyReviewItem) return 1;
        return 0;
      });

      result.add(
        PathUnitData(
          unit: vocabUnit,
          items: items,
          completedNodeTypes: nodeCompletions[lpUnit.unitId] ?? {},
          sequentialLock: path.sequentialLock,
          booksExemptFromLock: path.booksExemptFromLock,
        ),
      );
    }
  }

  return result;
});

// ============================================
// DAILY WORD LIST LIMIT
// ============================================

/// Daily new word limit for word lists (like Anki's daily new card limit)
const int dailyWordListLimit = 30;

/// Count of words learned today from word lists only.
/// Uses vocabulary_progress + word_list_items join server-side.
final wordsStartedTodayFromListsProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;

  final useCase = ref.watch(getWordsFromListsLearnedTodayUseCaseProvider);
  final result = await useCase(GetWordsFromListsLearnedTodayParams(userId: userId));

  return result.fold(
    (failure) => 0,
    (count) => count,
  );
});

/// Whether a specific word list can be started (not locked by daily limit).
/// Always returns true for already-started lists.
/// Locks only when the user has already reached the daily limit.
final canStartWordListProvider = Provider.family<bool, String>((ref, listId) {
  // Already started → always allowed (exempt from limit)
  final progress = ref.watch(progressForListProvider(listId)).valueOrNull;
  if (progress != null) return true;

  // Check daily limit — lock only when limit is fully reached
  final wordsToday = ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
  return wordsToday < dailyWordListLimit;
});

/// Remaining daily word allowance
final remainingDailyWordAllowanceProvider = FutureProvider<int>((ref) async {
  final used = await ref.watch(wordsStartedTodayFromListsProvider.future);
  return (dailyWordListLimit - used).clamp(0, dailyWordListLimit);
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
// DAILY REVIEW GATE
// ============================================

/// Whether a daily review gate is active in the learning path.
/// Returns true when any unit has a pending (incomplete) PathDailyReviewItem.
/// Used by PathNode to block word list navigation until DR is done.
final dailyReviewNeededProvider = FutureProvider<bool>((ref) async {
  final pathUnits = await ref.watch(learningPathProvider.future);
  return pathUnits.any(
    (unit) => unit.items.any((i) => i is PathDailyReviewItem && !i.isComplete),
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

/// Mark a special path node as completed and refresh the learning path
Future<bool> completePathNode(WidgetRef ref, String unitId, String nodeType) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return false;

  final useCase = ref.read(completeNodeUseCaseProvider);
  final result = await useCase(
    CompleteNodeParams(userId: userId, unitId: unitId, nodeType: nodeType),
  );

  return result.fold(
    (failure) => false,
    (_) {
      ref.invalidate(nodeCompletionsProvider);
      return true;
    },
  );
}

/// Add a word to user's vocabulary
/// When [immediate] is true, the word appears in today's daily review
Future<VocabularyActionResult> addWordToVocabulary(
  WidgetRef ref,
  String wordId, {
  bool immediate = false,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    return const VocabularyActionResult(
      success: false,
      errorMessage: 'User not logged in',
    );
  }

  final useCase = ref.read(addWordToVocabularyUseCaseProvider);
  final result = await useCase(
    AddWordToVocabularyParams(userId: userId, wordId: wordId, immediate: immediate),
  );

  return result.fold(
    (failure) => VocabularyActionResult(
      success: false,
      errorMessage: failure.message,
    ),
    (_) {
      // Invalidate so Word Bank and Daily Review see the new word
      ref.invalidate(userVocabularyProgressProvider);
      return const VocabularyActionResult(success: true);
    },
  );
}
