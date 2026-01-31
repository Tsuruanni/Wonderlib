import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/reading_progress.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Provides all published books with optional filters
final booksProvider = FutureProvider.family<List<Book>, BookFilters?>((ref, filters) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getBooks(
    level: filters?.level,
    genre: filters?.genre,
    ageGroup: filters?.ageGroup,
    page: filters?.page ?? 1,
    pageSize: filters?.pageSize ?? 20,
  );
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides a single book by ID
final bookByIdProvider = FutureProvider.family<Book?, String>((ref, id) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getBookById(id);
  return result.fold(
    (failure) => null,
    (book) => book,
  );
});

/// Provides book search results
final bookSearchProvider = FutureProvider.family<List<Book>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.searchBooks(query);
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides recommended books for current user
final recommendedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getRecommendedBooks(userId);
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides books user is currently reading
final continueReadingProvider = FutureProvider<List<Book>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getContinueReading(userId);
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides chapters for a book
final chaptersProvider = FutureProvider.family<List<Chapter>, String>((ref, bookId) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getChapters(bookId);
  return result.fold(
    (failure) => [],
    (chapters) => chapters,
  );
});

/// Provides a single chapter by ID
final chapterByIdProvider = FutureProvider.family<Chapter?, String>((ref, chapterId) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getChapterById(chapterId);
  return result.fold(
    (failure) => null,
    (chapter) => chapter,
  );
});

/// Provides reading progress for a book
final readingProgressProvider = FutureProvider.family<ReadingProgress?, String>((ref, bookId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final bookRepo = ref.watch(bookRepositoryProvider);
  final result = await bookRepo.getReadingProgress(
    userId: userId,
    bookId: bookId,
  );
  return result.fold(
    (failure) => null,
    (progress) => progress,
  );
});

/// Notifier for marking chapters as complete
class ChapterCompletionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ChapterCompletionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> markComplete({
    required String bookId,
    required String chapterId,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    final bookRepo = _ref.read(bookRepositoryProvider);
    final result = await bookRepo.markChapterComplete(
      userId: userId,
      bookId: bookId,
      chapterId: chapterId,
    );

    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (progress) {
        state = const AsyncValue.data(null);
        // Invalidate reading progress to refresh UI
        _ref.invalidate(readingProgressProvider(bookId));
      },
    );
  }
}

/// Provider for chapter completion notifier
final chapterCompletionProvider =
    StateNotifierProvider<ChapterCompletionNotifier, AsyncValue<void>>((ref) {
  return ChapterCompletionNotifier(ref);
});

/// Book filters
class BookFilters {
  final String? level;
  final String? genre;
  final String? ageGroup;
  final int page;
  final int pageSize;

  const BookFilters({
    this.level,
    this.genre,
    this.ageGroup,
    this.page = 1,
    this.pageSize = 20,
  });

  BookFilters copyWith({
    String? level,
    String? genre,
    String? ageGroup,
    int? page,
    int? pageSize,
  }) {
    return BookFilters(
      level: level ?? this.level,
      genre: genre ?? this.genre,
      ageGroup: ageGroup ?? this.ageGroup,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Reading controller for updating progress
class ReadingController extends StateNotifier<AsyncValue<ReadingProgress?>> {
  final Ref _ref;
  final String bookId;

  ReadingController(this._ref, this.bookId) : super(const AsyncValue.loading()) {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final bookRepo = _ref.read(bookRepositoryProvider);
    final result = await bookRepo.getReadingProgress(
      userId: userId,
      bookId: bookId,
    );

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (progress) => AsyncValue.data(progress),
    );
  }

  Future<void> updateProgress({
    String? chapterId,
    int? currentPage,
    double? completionPercentage,
    int? additionalReadingTime,
    bool? isCompleted,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      chapterId: chapterId ?? current.chapterId,
      currentPage: currentPage ?? current.currentPage,
      completionPercentage: completionPercentage ?? current.completionPercentage,
      totalReadingTime: current.totalReadingTime + (additionalReadingTime ?? 0),
      isCompleted: isCompleted ?? current.isCompleted,
      completedAt: (isCompleted ?? false) ? DateTime.now() : current.completedAt,
      updatedAt: DateTime.now(),
    );

    final bookRepo = _ref.read(bookRepositoryProvider);
    final result = await bookRepo.updateReadingProgress(updated);

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (progress) => AsyncValue.data(progress),
    );
  }
}

final readingControllerProvider = StateNotifierProvider.family<
    ReadingController, AsyncValue<ReadingProgress?>, String>((ref, bookId) {
  return ReadingController(ref, bookId);
});
