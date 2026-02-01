import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/student_assignment_repository.dart';
import '../../domain/usecases/book/get_book_by_id_usecase.dart';
import '../../domain/usecases/book/get_books_usecase.dart';
import '../../domain/usecases/book/get_chapter_by_id_usecase.dart';
import '../../domain/usecases/book/get_chapters_usecase.dart';
import '../../domain/usecases/book/get_continue_reading_usecase.dart';
import '../../domain/usecases/book/get_recommended_books_usecase.dart';
import '../../domain/usecases/book/search_books_usecase.dart';
import '../../domain/usecases/reading/update_reading_progress_usecase.dart';
import '../../domain/usecases/reading/get_reading_progress_usecase.dart';
import '../../domain/usecases/reading/mark_chapter_complete_usecase.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/update_assignment_progress_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import 'auth_provider.dart';
import 'student_assignment_provider.dart';
import 'usecase_providers.dart';

/// Provides all published books with optional filters
final booksProvider = FutureProvider.family<List<Book>, BookFilters?>((ref, filters) async {
  final useCase = ref.watch(getBooksUseCaseProvider);
  final result = await useCase(GetBooksParams(
    level: filters?.level,
    genre: filters?.genre,
    ageGroup: filters?.ageGroup,
    page: filters?.page ?? 1,
    pageSize: filters?.pageSize ?? 20,
  ),);
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides a single book by ID
final bookByIdProvider = FutureProvider.family<Book?, String>((ref, id) async {
  final useCase = ref.watch(getBookByIdUseCaseProvider);
  final result = await useCase(GetBookByIdParams(bookId: id));
  return result.fold(
    (failure) => null,
    (book) => book,
  );
});

/// Provides book search results
final bookSearchProvider = FutureProvider.family<List<Book>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final useCase = ref.watch(searchBooksUseCaseProvider);
  final result = await useCase(SearchBooksParams(query: query));
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides recommended books for current user
final recommendedBooksProvider = FutureProvider<List<Book>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getRecommendedBooksUseCaseProvider);
  final result = await useCase(GetRecommendedBooksParams(userId: userId));
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides books user is currently reading
final continueReadingProvider = FutureProvider<List<Book>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final useCase = ref.watch(getContinueReadingUseCaseProvider);
  final result = await useCase(GetContinueReadingParams(userId: userId));
  return result.fold(
    (failure) => [],
    (books) => books,
  );
});

/// Provides chapters for a book
final chaptersProvider = FutureProvider.family<List<Chapter>, String>((ref, bookId) async {
  final useCase = ref.watch(getChaptersUseCaseProvider);
  final result = await useCase(GetChaptersParams(bookId: bookId));
  return result.fold(
    (failure) => [],
    (chapters) => chapters,
  );
});

/// Provides a single chapter by ID
final chapterByIdProvider = FutureProvider.family<Chapter?, String>((ref, chapterId) async {
  final useCase = ref.watch(getChapterByIdUseCaseProvider);
  final result = await useCase(GetChapterByIdParams(chapterId: chapterId));
  return result.fold(
    (failure) => null,
    (chapter) => chapter,
  );
});

/// Provides reading progress for a book
final readingProgressProvider = FutureProvider.family<ReadingProgress?, String>((ref, bookId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getReadingProgressUseCaseProvider);
  final result = await useCase(GetReadingProgressParams(
    userId: userId,
    bookId: bookId,
  ),);
  return result.fold(
    (failure) => null,
    (progress) => progress,
  );
});

/// Notifier for marking chapters as complete
class ChapterCompletionNotifier extends StateNotifier<AsyncValue<void>> {

  ChapterCompletionNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> markComplete({
    required String bookId,
    required String chapterId,
  }) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    state = const AsyncValue.loading();

    final useCase = _ref.read(markChapterCompleteUseCaseProvider);
    final result = await useCase(MarkChapterCompleteParams(
      userId: userId,
      bookId: bookId,
      chapterId: chapterId,
    ),);

    result.fold(
      (failure) => state = AsyncValue.error(failure, StackTrace.current),
      (progress) async {
        state = const AsyncValue.data(null);
        // Invalidate providers to refresh UI
        _ref.invalidate(readingProgressProvider(bookId));
        _ref.invalidate(continueReadingProvider); // Refresh continue reading list

        // Update assignment progress if this book is part of an assignment
        await _updateAssignmentProgress(
          userId: userId,
          bookId: bookId,
          chapterId: chapterId,
          completedChapterIds: progress.completedChapterIds,
        );
      },
    );
  }

  /// Check if book is part of an active assignment and update progress
  Future<void> _updateAssignmentProgress({
    required String userId,
    required String bookId,
    required String chapterId,
    required List<String> completedChapterIds,
  }) async {
    try {
      // Get active assignments using UseCase
      final getActiveAssignmentsUseCase = _ref.read(getActiveAssignmentsUseCaseProvider);
      final assignmentsResult = await getActiveAssignmentsUseCase(
        GetActiveAssignmentsParams(studentId: userId),
      );

      assignmentsResult.fold(
        (failure) {}, // Silently fail - don't break chapter completion
        (assignments) async {
          // Find assignments that include this book
          for (final assignment in assignments) {
            if (assignment.bookId == bookId &&
                assignment.status != StudentAssignmentStatus.completed) {
              // Get all chapters for the book (book-based assignments)
              final getChaptersUseCase = _ref.read(getChaptersUseCaseProvider);
              final chaptersResult = await getChaptersUseCase(
                GetChaptersParams(bookId: bookId),
              );

              final totalChapters = chaptersResult.fold(
                (failure) => 0,
                (chapters) => chapters.length,
              );

              if (totalChapters == 0) {
                continue;
              }

              // Calculate progress: completed chapters / total chapters in book
              final progress = (completedChapterIds.length / totalChapters) * 100;

              // Update assignment progress using UseCases
              if (progress >= 100) {
                // All chapters complete - mark assignment as complete
                final completeAssignmentUseCase = _ref.read(completeAssignmentUseCaseProvider);
                await completeAssignmentUseCase(CompleteAssignmentParams(
                  studentId: userId,
                  assignmentId: assignment.assignmentId,
                  score: null, // No score for reading completion
                ),);
              } else {
                // Update progress
                final updateAssignmentProgressUseCase = _ref.read(updateAssignmentProgressUseCaseProvider);
                await updateAssignmentProgressUseCase(UpdateAssignmentProgressParams(
                  studentId: userId,
                  assignmentId: assignment.assignmentId,
                  progress: progress,
                ),);
              }

              // Invalidate assignment providers to refresh UI
              _ref.invalidate(studentAssignmentsProvider);
              _ref.invalidate(activeAssignmentsProvider);
              _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
            }
          }
        },
      );
    } catch (e) {
      // Don't throw - assignment update failure shouldn't break chapter completion
    }
  }
}

/// Provider for chapter completion notifier
final chapterCompletionProvider =
    StateNotifierProvider.autoDispose<ChapterCompletionNotifier, AsyncValue<void>>((ref) {
  return ChapterCompletionNotifier(ref);
});

/// Book filters
class BookFilters {

  const BookFilters({
    this.level,
    this.genre,
    this.ageGroup,
    this.page = 1,
    this.pageSize = 20,
  });
  final String? level;
  final String? genre;
  final String? ageGroup;
  final int page;
  final int pageSize;

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

  ReadingController(this._ref, this.bookId) : super(const AsyncValue.loading()) {
    _loadProgress();
  }
  final Ref _ref;
  final String bookId;

  Future<void> _loadProgress() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    final useCase = _ref.read(getReadingProgressUseCaseProvider);
    final result = await useCase(GetReadingProgressParams(
      userId: userId,
      bookId: bookId,
    ),);

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

    final useCase = _ref.read(updateReadingProgressUseCaseProvider);
    final result = await useCase(UpdateReadingProgressParams(progress: updated));

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (progress) => AsyncValue.data(progress),
    );
  }
}

final readingControllerProvider = StateNotifierProvider.autoDispose.family<
    ReadingController, AsyncValue<ReadingProgress?>, String>((ref, bookId) {
  return ReadingController(ref, bookId);
});
