import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/vocabulary.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

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
