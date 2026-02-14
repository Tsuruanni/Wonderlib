import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/book_quiz.dart';

abstract class BookQuizRepository {
  /// Get the quiz for a book (null if no published quiz)
  Future<Either<Failure, BookQuiz?>> getQuizForBook(String bookId);

  /// Check if a book has a published quiz
  Future<Either<Failure, bool>> bookHasQuiz(String bookId);

  /// Submit quiz result (returns the persisted result with attempt_number)
  Future<Either<Failure, BookQuizResult>> submitQuizResult(
    BookQuizResult result,
  );

  /// Get user's best quiz result for a book
  Future<Either<Failure, BookQuizResult?>> getBestResult({
    required String userId,
    required String bookId,
  });

  /// Get all quiz attempts for a user+book
  Future<Either<Failure, List<BookQuizResult>>> getUserQuizResults({
    required String userId,
    required String bookId,
  });

  /// Get student quiz results across all books (for teacher reporting)
  Future<Either<Failure, List<StudentQuizProgress>>> getStudentQuizResults(
    String studentId,
  );
}
