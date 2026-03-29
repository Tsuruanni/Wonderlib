import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../domain/entities/tile_theme.dart';
import '../widgets/learning_path/tile_themes.dart';
import 'tile_theme_provider.dart';

import '../../domain/entities/book.dart';
import '../../domain/entities/daily_review_session.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/entities/student_assignment.dart';
import '../../domain/entities/vocabulary_session.dart';
import '../../domain/usecases/book/get_books_by_ids_usecase.dart';
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../domain/usecases/wordlist/complete_session_usecase.dart';
import 'book_provider.dart';
import 'daily_quest_provider.dart';
import 'daily_review_provider.dart';
import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/vocabulary_unit.dart';
import '../../domain/entities/word_list.dart';
import '../../domain/usecases/vocabulary/complete_node_usecase.dart';
import '../../domain/usecases/wordlist/get_user_learning_paths_usecase.dart';
import '../../domain/usecases/vocabulary/get_node_completions_usecase.dart';
import '../../domain/usecases/vocabulary/get_all_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_new_words_usecase.dart';
import '../../domain/usecases/vocabulary/get_user_vocabulary_progress_usecase.dart';
import '../../domain/usecases/vocabulary/get_vocabulary_stats_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_by_ids_usecase.dart';
import '../../domain/usecases/vocabulary/search_words_usecase.dart';
import '../../domain/usecases/vocabulary/add_word_to_vocabulary_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_from_lists_learned_today_usecase.dart';
import '../../domain/usecases/vocabulary/get_words_learned_today_usecase.dart';
import '../../domain/usecases/wordlist/get_all_word_lists_usecase.dart';
import '../../domain/usecases/wordlist/get_progress_for_list_usecase.dart';
import '../../domain/usecases/wordlist/get_user_word_list_progress_usecase.dart';
import '../../domain/usecases/wordlist/get_word_list_by_id_usecase.dart';
import '../../domain/usecases/wordlist/get_words_for_list_usecase.dart';
import 'auth_provider.dart';
import 'leaderboard_provider.dart';
import 'student_assignment_provider.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';

// ============================================
// TOP-LEVEL PROVIDERS
// ============================================

/// Y position of the active (current) node in the learning path.
/// Uses per-theme heights from DB when available, falls back to hardcoded themes.
final activeNodeYProvider = Provider<double?>((ref) {
  final pathUnits = ref.watch(learningPathProvider).valueOrNull;
  if (pathUnits == null || pathUnits.isEmpty) return null;

  final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

  var cumulativeY = 0.0;

  for (int unitIdx = 0; unitIdx < pathUnits.length; unitIdx++) {
    final unit = pathUnits[unitIdx];
    final isUnitLocked = unitIdx > 0 && !pathUnits[unitIdx - 1].isAllComplete;

    final themeHeight = _resolveThemeHeight(unit, unitIdx, dbThemes);
    final positions = _resolveThemePositions(unit, unitIdx, dbThemes);

    cumulativeY += kDividerHeight;

    final locks = calculateLocks(
      items: unit.items,
      sequentialLock: unit.sequentialLock,
      booksExemptFromLock: unit.booksExemptFromLock,
      isUnitLocked: isUnitLocked,
    );

    for (int itemIdx = 0; itemIdx < unit.items.length; itemIdx++) {
      final item = unit.items[itemIdx];
      final isItemLocked = locks[itemIdx];

      if (!isItemLocked && !item.isComplete && item is! PathDailyReviewItem) {
        if (itemIdx >= positions.length) continue;
        return cumulativeY + positions[itemIdx].dy * themeHeight;
      }
    }

    cumulativeY += themeHeight;
  }

  return null;
});

double _resolveThemeHeight(PathUnitData unit, int unitIdx, List<TileThemeEntity> dbThemes) {
  if (unit.unit.tileThemeId != null && dbThemes.isNotEmpty) {
    final match = dbThemes.where((t) => t.id == unit.unit.tileThemeId).firstOrNull;
    if (match != null) return match.height.toDouble();
  }
  return tileThemeForUnit(unitIdx).height;
}

List<Offset> _resolveThemePositions(PathUnitData unit, int unitIdx, List<TileThemeEntity> dbThemes) {
  if (unit.unit.tileThemeId != null && dbThemes.isNotEmpty) {
    final match = dbThemes.where((t) => t.id == unit.unit.tileThemeId).firstOrNull;
    if (match != null) return match.nodePositions.map((p) => Offset(p.x, p.y)).toList();
  }
  return tileThemeForUnit(unitIdx).nodePositions;
}

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

  // Batch fetch all words in a single query (instead of N sequential calls)
  final wordIds = progressList.map((p) => p.wordId).toList();
  final getWordsUseCase = ref.watch(getWordsByIdsUseCaseProvider);
  final result = await getWordsUseCase(GetWordsByIdsParams(ids: wordIds));

  final wordMap = result.fold(
    (_) => <String, VocabularyWord>{},
    (words) => {for (final w in words) w.id: w},
  );

  final items = <UserVocabularyItem>[];
  for (final progress in progressList) {
    final word = wordMap[progress.wordId];
    if (word != null) {
      items.add(UserVocabularyItem(word: word, progress: progress));
    }
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

/// Story vocabulary lists — derived from allWordListsProvider (no extra HTTP request)
final storyWordListsProvider = FutureProvider<List<WordList>>((ref) async {
  final allLists = await ref.watch(allWordListsProvider.future);
  return allLists.where((l) => l.category == WordListCategory.storyVocab).toList();
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

  double get progressPercentage {
    if (progress == null || !progress!.isComplete) return 0.0;
    return (progress!.bestAccuracy ?? 0) / 100.0;
  }
  bool get isStarted => progress != null;
  bool get isComplete => progress?.isComplete ?? false;
  int get starCount => progress?.starCount ?? 0;
  int starCountWith({int star3 = 90, int star2 = 70, int star1 = 50}) =>
      progress?.starCountWith(star3: star3, star2: star2, star1: star1) ?? 0;
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
  final user = await ref.watch(currentUserProvider.future);
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
  // Capture all ref.watch calls BEFORE the first await (Riverpod best practice)
  final getBooksByIds = ref.watch(getBooksByIdsUseCaseProvider);

  // Fetch all independent providers in parallel (not sequentially)
  final futures = await Future.wait([
    ref.watch(userLearningPathsProvider.future),       // [0]
    ref.watch(allWordListsProvider.future),             // [1]
    ref.watch(userWordListProgressProvider.future),     // [2]
    ref.watch(nodeCompletionsProvider.future),          // [3]
    ref.watch(completedBookIdsProvider.future),         // [4]
    ref.watch(todayReviewSessionProvider.future)        // [5]
        .catchError((_) => null),
    ref.watch(dailyReviewWordsProvider.future)    // [6]
        .catchError((_) => <VocabularyWord>[]),
  ]);

  final learningPaths = futures[0] as List<LearningPath>;
  final allLists = futures[1] as List<WordList>;
  final progressList = futures[2] as List<UserWordListProgress>;
  final nodeCompletions = futures[3] as Map<String, Set<String>>;
  final completedBookIds = futures[4] as Set<String>;
  final todaySession = futures[5] as DailyReviewSession?;
  final dailyReviewDueWords = futures[6] as List<VocabularyWord>;
  final dailyReviewDueCount = dailyReviewDueWords.length;

  if (learningPaths.isEmpty) return [];

  // Build lookup maps
  final progressMap = {for (final p in progressList) p.wordListId: p};
  final wordListMap = {for (final wl in allLists) wl.id: wl};

  // --- Daily Review ---
  final drDoneToday = todaySession != null;
  final drNeeded = dailyReviewDueCount >= minDailyReviewCount;
  bool drInjected = false; // only inject DR once across all units

  // Batch fetch all book items in a single query (instead of N+1 bookByIdProvider calls)
  final allBookIds = <String>{};
  for (final path in learningPaths) {
    for (final lpUnit in path.units) {
      for (final item in lpUnit.items) {
        if (item.itemType == LearningPathItemType.book) {
          allBookIds.add(item.itemId);
        }
      }
    }
  }
  final bookMap = <String, Book>{};
  if (allBookIds.isNotEmpty) {
    final result = await getBooksByIds(GetBooksByIdsParams(ids: allBookIds.toList()));
    result.fold(
      (_) {},
      (books) {
        for (final book in books) {
          bookMap[book.id] = book;
        }
      },
    );
  }

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
          final book = bookMap[item.itemId];
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

      // --- Daily Review injection (only once across all units) ---
      if (!drInjected && (drNeeded || drDoneToday)) {
        // Check if this unit has incomplete non-exempt items (DR belongs here)
        final hasIncompleteHere = items.any((item) {
          final isExempt = item is PathBookItem && path.booksExemptFromLock;
          return !isExempt && !item.isComplete;
        });

        if (hasIncompleteHere || drDoneToday) {
          int drSortOrder;

          if (drDoneToday && todaySession!.pathPosition != null) {
            // Completed DR: use the saved position (stays fixed)
            drSortOrder = todaySession.pathPosition!;
          } else {
            // Pending DR: position before the first incomplete non-exempt item
            drSortOrder = items.isEmpty ? 0 : items.last.sortOrder + 1;
            for (int i = 0; i < items.length; i++) {
              final item = items[i];
              final isExempt = item is PathBookItem && path.booksExemptFromLock;
              if (!isExempt && !item.isComplete) {
                drSortOrder = item.sortOrder;
                break;
              }
            }
          }

          items.add(PathDailyReviewItem(
            sortOrder: drSortOrder,
            completedAt: drDoneToday ? todaySession!.completedAt : null,
            isCompleted: drDoneToday,
          ));
          drInjected = true; // Don't inject again in other units
        }
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
      ref.invalidate(learnedWordsWithDetailsProvider);
      ref.invalidate(dailyReviewWordsProvider);
      return const VocabularyActionResult(success: true);
    },
  );
}

// ============================================
// SESSION SAVE
// ============================================

enum SessionSaveStatus { idle, saving, saved, error }

class SessionSaveState {
  const SessionSaveState({
    this.status = SessionSaveStatus.idle,
    this.actualXpAwarded,
    this.errorMessage,
  });

  final SessionSaveStatus status;
  final int? actualXpAwarded;
  final String? errorMessage;
}

class SessionSaveNotifier extends StateNotifier<SessionSaveState> {
  SessionSaveNotifier(this._ref) : super(const SessionSaveState());

  final Ref _ref;

  Future<void> save({
    required String userId,
    required String listId,
    required int totalQuestions,
    required int correctCount,
    required int incorrectCount,
    required double accuracy,
    required int maxCombo,
    required int xpEarned,
    required int durationSeconds,
    required int wordsStrong,
    required int wordsWeak,
    required int firstTryPerfectCount,
    required List<SessionWordResult> wordResults,
  }) async {
    if (state.status == SessionSaveStatus.saving) return;
    state = const SessionSaveState(status: SessionSaveStatus.saving);

    final completeSessionUseCase = _ref.read(completeSessionUseCaseProvider);
    final result = await completeSessionUseCase(CompleteSessionParams(
      userId: userId,
      wordListId: listId,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      accuracy: accuracy,
      maxCombo: maxCombo,
      xpEarned: xpEarned,
      durationSeconds: durationSeconds,
      wordsStrong: wordsStrong,
      wordsWeak: wordsWeak,
      firstTryPerfectCount: firstTryPerfectCount,
      wordResults: wordResults,
    ));

    if (!mounted) return;

    result.fold(
      (failure) {
        if (!mounted) return;
        state = SessionSaveState(
          status: SessionSaveStatus.error,
          errorMessage: failure.message,
        );
      },
      (savedResult) {
        if (!mounted) return;
        // Invalidate all dependent providers
        _ref.invalidate(progressForListProvider(listId));
        _ref.invalidate(userWordListProgressProvider);
        _ref.invalidate(wordListsWithProgressProvider);
        _ref.invalidate(learningPathProvider);
        _ref.invalidate(userVocabularyProgressProvider);
        _ref.invalidate(learnedWordsWithDetailsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        _ref.invalidate(leaderboardEntriesProvider);
        _ref.invalidate(dailyQuestProgressProvider);

        // Complete matching assignments (best-effort)
        _completeAssignments(userId: userId, listId: listId, accuracy: accuracy);

        state = SessionSaveState(
          status: SessionSaveStatus.saved,
          actualXpAwarded: savedResult.xpEarned,
        );
      },
    );
  }

  Future<void> _completeAssignments({
    required String userId,
    required String listId,
    required double accuracy,
  }) async {
    try {
      if (!mounted) return;
      final getActiveAssignmentsUseCase = _ref.read(getActiveAssignmentsUseCaseProvider);
      final result = await getActiveAssignmentsUseCase(
        GetActiveAssignmentsParams(studentId: userId),
      );

      if (!mounted) return;
      final assignments = result.fold(
        (failure) => <StudentAssignment>[],
        (assignments) => assignments,
      );

      for (final assignment in assignments) {
        if (!mounted) return;
        if (assignment.wordListId == listId &&
            assignment.status != StudentAssignmentStatus.completed) {
          final completeAssignmentUseCase = _ref.read(completeAssignmentUseCaseProvider);
          await completeAssignmentUseCase(CompleteAssignmentParams(
            studentId: userId,
            assignmentId: assignment.assignmentId,
            score: accuracy,
          ));
          if (!mounted) return;
          _ref.invalidate(studentAssignmentsProvider);
          _ref.invalidate(activeAssignmentsProvider);
          _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }

      // Check unit assignments
      for (final assignment in assignments) {
        if (!mounted) return;
        if (assignment.scopeLpUnitId != null &&
            assignment.status != StudentAssignmentStatus.completed) {
          final calculateUseCase = _ref.read(calculateUnitProgressUseCaseProvider);
          await calculateUseCase(CalculateUnitProgressParams(
            assignmentId: assignment.assignmentId,
            studentId: userId,
          ));
          if (!mounted) return;
          _ref.invalidate(studentAssignmentsProvider);
          _ref.invalidate(activeAssignmentsProvider);
          _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }
    } catch (_) {
      // Assignment completion is best-effort; session save already succeeded
    }
  }
}

final sessionSaveProvider =
    StateNotifierProvider.autoDispose<SessionSaveNotifier, SessionSaveState>(
  (ref) => SessionSaveNotifier(ref),
);
