import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_assignment.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/usecases/book/get_book_by_id_usecase.dart';
import '../../domain/usecases/book/get_books_usecase.dart';
import '../../domain/usecases/book/get_chapters_usecase.dart';
import '../../domain/usecases/book/get_completed_book_ids_usecase.dart';
import '../../domain/usecases/book/get_continue_reading_usecase.dart';
import '../../domain/usecases/book/search_books_usecase.dart';
import '../../domain/usecases/reading/check_read_today_usecase.dart';
import '../../domain/usecases/reading/get_reading_progress_usecase.dart';
import 'daily_quest_provider.dart';
import 'monthly_quest_provider.dart';
import '../../domain/usecases/reading/handle_book_completion_usecase.dart';
import '../../domain/usecases/reading/mark_chapter_complete_usecase.dart';
import '../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../domain/usecases/student_assignment/update_assignment_progress_usecase.dart';
import '../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
import '../../domain/entities/system_settings.dart';
import 'system_settings_provider.dart';
import 'teacher_preview_provider.dart';
import 'auth_provider.dart';
import 'student_assignment_provider.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';

class ChapterWithLockStatus {
  const ChapterWithLockStatus({
    required this.chapter,
    required this.isLocked,
    required this.isCompleted,
  });
  final Chapter chapter;
  final bool isLocked;
  final bool isCompleted;
}

final chaptersWithLockStatusProvider =
    Provider.family<List<ChapterWithLockStatus>, String>((ref, bookId) {
  final chapters = ref.watch(chaptersProvider(bookId)).valueOrNull ?? [];
  final progress = ref.watch(readingProgressProvider(bookId)).valueOrNull;
  final completedIds = progress?.completedChapterIds ?? [];
  final isPreview = ref.watch(isTeacherPreviewModeProvider);

  return chapters.indexed.map((e) {
    final (index, chapter) = e;
    final isLocked = !isPreview &&
        index > 0 &&
        chapters.take(index).any((c) => !completedIds.contains(c.id));
    return ChapterWithLockStatus(
      chapter: chapter,
      isLocked: isLocked,
      isCompleted: completedIds.contains(chapter.id),
    );
  }).toList();
});

/// Provides all published books with optional filters
final booksProvider = FutureProvider.autoDispose.family<List<Book>, BookFilters?>((ref, filters) async {
  final useCase = ref.watch(getBooksUseCaseProvider);
  final result = await useCase(GetBooksParams(
    level: filters?.level,
    genre: filters?.genre,
    ageGroup: filters?.ageGroup,
    page: filters?.page ?? 1,
    pageSize: filters?.pageSize ?? 20,
  ),);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (books) => books,
  );
});

/// Provides a single book by ID
final bookByIdProvider = FutureProvider.autoDispose.family<Book?, String>((ref, id) async {
  final useCase = ref.watch(getBookByIdUseCaseProvider);
  final result = await useCase(GetBookByIdParams(bookId: id));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (book) => book,
  );
});

/// Provides book search results
final bookSearchProvider = FutureProvider.autoDispose.family<List<Book>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final useCase = ref.watch(searchBooksUseCaseProvider);
  final result = await useCase(SearchBooksParams(query: query));
  return result.fold(
    (failure) => throw Exception(failure.message),
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
    (failure) => throw Exception(failure.message),
    (books) => books,
  );
});

/// Provides chapters for a book
final chaptersProvider = FutureProvider.autoDispose.family<List<Chapter>, String>((ref, bookId) async {
  final useCase = ref.watch(getChaptersUseCaseProvider);
  final result = await useCase(GetChaptersParams(bookId: bookId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (chapters) => chapters,
  );
});

/// Provides a single chapter by ID, filtered from the already-loaded batch (no extra network call)
final chapterByIdProvider = FutureProvider.family<Chapter?, ({String bookId, String chapterId})>(
  (ref, params) async {
    final chapters = await ref.watch(chaptersProvider(params.bookId).future);
    return chapters.where((c) => c.id == params.chapterId).firstOrNull;
  },
);

/// Provides reading progress for a book
final readingProgressProvider = FutureProvider.autoDispose.family<ReadingProgress?, String>((ref, bookId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final useCase = ref.watch(getReadingProgressUseCaseProvider);
  final result = await useCase(GetReadingProgressParams(
    userId: userId,
    bookId: bookId,
  ),);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (progress) => progress,
  );
});

/// Provides set of completed book IDs for current user
final completedBookIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final useCase = ref.watch(getCompletedBookIdsUseCaseProvider);
  final result = await useCase(GetCompletedBookIdsParams(userId: userId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (bookIds) => bookIds,
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

    // Extract progress from result (don't use async callback in fold)
    final progress = result.fold(
      (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return null;
      },
      (progress) => progress,
    );

    if (progress != null) {
      // Check if this chapter was newly completed (prevent duplicate XP)
      final previousProgress = _ref.read(readingProgressProvider(bookId)).valueOrNull;
      final wasAlreadyCompleted = previousProgress?.completedChapterIds.contains(chapterId) ?? false;
      debugPrint('📖 markComplete: bookId=$bookId, chapterId=$chapterId, wasAlreadyCompleted=$wasAlreadyCompleted');

      state = const AsyncValue.data(null);
      // Invalidate providers to refresh UI
      _ref.invalidate(readingProgressProvider(bookId));
      _ref.invalidate(continueReadingProvider); // Refresh continue reading list
      debugPrint('📖 markComplete: invalidating dailyQuestProgressProvider');
      _ref.invalidate(dailyQuestProgressProvider); // Refresh daily quest
      _ref.invalidate(monthlyQuestProgressProvider); // Refresh monthly quest

      // Award XP for new chapter completion
      if (!wasAlreadyCompleted) {
        final settings = _ref.read(systemSettingsProvider).valueOrNull ?? SystemSettings.defaults();
        await _ref.read(userControllerProvider.notifier).addXP(
          settings.xpChapterComplete,
          source: 'chapter_complete',
          sourceId: chapterId,
        );

        // Check if book is now complete (quiz-less books complete here)
        final completionUseCase = _ref.read(handleBookCompletionUseCaseProvider);
        final completionResult = await completionUseCase(
          HandleBookCompletionParams(
            userId: userId,
            bookId: bookId,
          ),
        );

        final justCompleted = completionResult.fold(
          (_) => false,
          (result) => result.justCompleted && !result.hasQuiz,
        );

        if (justCompleted) {
          await _ref.read(userControllerProvider.notifier).addXP(
            settings.xpBookComplete,
            source: 'book_complete',
            sourceId: bookId,
          );

          // Re-invalidate after completion write to avoid stale cache
          // (first invalidation races against the completion DB write)
          _ref.invalidate(readingProgressProvider(bookId));
          _ref.invalidate(completedBookIdsProvider);
          _ref.invalidate(continueReadingProvider);
        }
      }

      // Update assignment progress if this book is part of an assignment
      await _updateAssignmentProgress(
        userId: userId,
        bookId: bookId,
        chapterId: chapterId,
        completedChapterIds: progress.completedChapterIds,
      );
    }
  }

  /// Check if book is part of an active assignment and update progress
  Future<void> _updateAssignmentProgress({
    required String userId,
    required String bookId,
    required String chapterId,
    required List<String> completedChapterIds,
  }) async {
    debugPrint('📋 _updateAssignmentProgress: bookId=$bookId, completedChapters=${completedChapterIds.length}');
    try {
      // Get active assignments using UseCase
      final getActiveAssignmentsUseCase = _ref.read(getActiveAssignmentsUseCaseProvider);
      final assignmentsResult = await getActiveAssignmentsUseCase(
        GetActiveAssignmentsParams(studentId: userId),
      );

      // Extract assignments from result (don't use async callback in fold)
      final assignments = assignmentsResult.fold(
        (failure) {
          debugPrint('📋 _updateAssignmentProgress: Failed to get assignments: ${failure.message}');
          return <StudentAssignment>[];
        },
        (assignments) => assignments,
      );

      debugPrint('📋 _updateAssignmentProgress: Found ${assignments.length} active assignments');

      // Find assignments that include this book
      for (final assignment in assignments) {
        debugPrint('📋 Checking assignment: ${assignment.title}, bookId=${assignment.bookId}, status=${assignment.status}');
        if (assignment.bookId == bookId &&
            assignment.status != StudentAssignmentStatus.completed) {
          debugPrint('📋 Match! Processing assignment: ${assignment.title}');
          // Get all chapters for the book (book-based assignments)
          final getChaptersUseCase = _ref.read(getChaptersUseCaseProvider);
          final chaptersResult = await getChaptersUseCase(
            GetChaptersParams(bookId: bookId),
          );

          final totalChapters = chaptersResult.fold(
            (failure) => 0,
            (chapters) => chapters.length,
          );

          debugPrint('📋 Total chapters: $totalChapters, completed: ${completedChapterIds.length}');

          if (totalChapters == 0) {
            continue;
          }

          // Calculate progress: completed chapters / total chapters in book
          final progress = (completedChapterIds.length / totalChapters) * 100;
          debugPrint('📋 Calculated progress: $progress%');

          // Update assignment progress using UseCases
          if (progress >= 100) {
            // All chapters read — but book may require quiz to be "completed".
            // Check reading_progress.isCompleted which respects quiz gates.
            final rpUseCase = _ref.read(getReadingProgressUseCaseProvider);
            final rpResult = await rpUseCase(
              GetReadingProgressParams(userId: userId, bookId: bookId),
            );
            final isBookCompleted = rpResult.fold(
              (_) => false,
              (rp) => rp.isCompleted,
            );

            if (isBookCompleted) {
              debugPrint('📋 Completing assignment: ${assignment.assignmentId}');
              final completeAssignmentUseCase = _ref.read(completeAssignmentUseCaseProvider);
              final result = await completeAssignmentUseCase(CompleteAssignmentParams(
                studentId: userId,
                assignmentId: assignment.assignmentId,
                score: null,
              ),);
              debugPrint('📋 Complete assignment result: ${result.isRight() ? "success" : "failed"}');
            } else {
              debugPrint('📋 All chapters read but book not completed (quiz pending), updating progress only');
              final updateAssignmentProgressUseCase = _ref.read(updateAssignmentProgressUseCaseProvider);
              await updateAssignmentProgressUseCase(UpdateAssignmentProgressParams(
                studentId: userId,
                assignmentId: assignment.assignmentId,
                progress: progress,
              ),);
            }
          } else {
            debugPrint('📋 Updating progress: ${assignment.assignmentId} to $progress%');
            // Update progress
            final updateAssignmentProgressUseCase = _ref.read(updateAssignmentProgressUseCaseProvider);
            await updateAssignmentProgressUseCase(UpdateAssignmentProgressParams(
              studentId: userId,
              assignmentId: assignment.assignmentId,
              progress: progress,
            ),);
          }

          // Invalidate assignment providers to refresh UI
          debugPrint('📋 Invalidating assignment providers');
          _ref.invalidate(studentAssignmentsProvider);
          _ref.invalidate(activeAssignmentsProvider);
          _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));

          // If book is completed, refresh completed books provider
          if (progress >= 100) {
            _ref.invalidate(completedBookIdsProvider);
          }
        }
      }

      // Recalculate unit assignments that might contain this book.
      // Client-side filtering is not possible here: the StudentAssignment entity
      // only carries scopeLpUnitId in contentConfig — the list of book IDs that
      // belong to the unit lives in scope_unit_items (server-side only).
      // The RPC checks scope_unit_items server-side and is a no-op when the
      // completed book is not part of the unit, so extra calls are safe.
      for (final assignment in assignments) {
        if (assignment.scopeLpUnitId != null &&
            assignment.status != StudentAssignmentStatus.completed) {
          debugPrint('📋 Unit assignment: ${assignment.title}, recalculating progress');
          final calculateUseCase = _ref.read(calculateUnitProgressUseCaseProvider);
          await calculateUseCase(CalculateUnitProgressParams(
            assignmentId: assignment.assignmentId,
            studentId: userId,
          ));
          _ref.invalidate(studentAssignmentsProvider);
          _ref.invalidate(activeAssignmentsProvider);
          _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }
    } catch (e) {
      debugPrint('📋 _updateAssignmentProgress ERROR: $e');
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

/// Whether user has read today (for daily task)
final hasReadTodayProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final useCase = ref.watch(checkReadTodayUseCaseProvider);
  final result = await useCase(CheckReadTodayParams(userId: userId));
  return result.fold(
    (failure) => throw Exception(failure.message),
    (hasRead) => hasRead,
  );
});

