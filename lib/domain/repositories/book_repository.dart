import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/activity.dart';
import '../entities/book.dart';
import '../entities/chapter.dart';
import '../entities/reading_progress.dart';

abstract class BookRepository {
  Future<Either<Failure, List<Book>>> getBooks({
    String? level,
    String? genre,
    String? ageGroup,
    int page = 1,
    int pageSize = 20,
  });

  Future<Either<Failure, Book>> getBookById(String id);

  Future<Either<Failure, List<Book>>> searchBooks(String query);

  Future<Either<Failure, List<Book>>> getRecommendedBooks(String userId);

  Future<Either<Failure, List<Chapter>>> getChapters(String bookId);

  Future<Either<Failure, Chapter>> getChapterById(String chapterId);

  Future<Either<Failure, ReadingProgress>> getReadingProgress({
    required String userId,
    required String bookId,
  });

  Future<Either<Failure, ReadingProgress>> updateReadingProgress(
    ReadingProgress progress,
  );

  Future<Either<Failure, List<ReadingProgress>>> getUserReadingHistory(
    String userId,
  );

  Future<Either<Failure, List<Book>>> getContinueReading(String userId);

  Future<Either<Failure, ReadingProgress>> markChapterComplete({
    required String userId,
    required String bookId,
    required String chapterId,
  });

  Future<Either<Failure, List<InlineActivity>>> getInlineActivities(
    String chapterId,
  );

  /// Saves inline activity result and returns whether this is a NEW completion.
  /// Returns `Right(true)` if newly completed, `Right(false)` if already existed.
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
  });

  Future<Either<Failure, List<String>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  });

  /// Updates the current chapter being read (for Continue Reading feature)
  Future<Either<Failure, void>> updateCurrentChapter({
    required String userId,
    required String bookId,
    required String chapterId,
  });

  /// Gets set of completed book IDs for a user
  Future<Either<Failure, Set<String>>> getCompletedBookIds(String userId);

  /// Check if user has read today (any reading_progress updated today)
  Future<Either<Failure, bool>> hasReadToday(String userId);

  /// Count correct answers today (inline_activity_results)
  Future<Either<Failure, int>> getCorrectAnswersTodayCount(String userId);

  /// Count words read today (from completed chapters)
  Future<Either<Failure, int>> getWordsReadTodayCount(String userId);
}
