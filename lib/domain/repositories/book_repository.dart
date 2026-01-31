import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
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
}
