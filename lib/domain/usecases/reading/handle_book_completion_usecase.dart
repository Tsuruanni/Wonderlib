import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class HandleBookCompletionParams {
  const HandleBookCompletionParams({
    required this.userId,
    required this.bookId,
    this.quizJustPassed = false,
  });
  final String userId;
  final String bookId;
  final bool quizJustPassed;
}

class BookCompletionResult {
  const BookCompletionResult({
    required this.progress,
    required this.justCompleted,
    required this.hasQuiz,
  });
  final ReadingProgress progress;
  final bool justCompleted;
  final bool hasQuiz;
}

class HandleBookCompletionUseCase
    implements UseCase<BookCompletionResult, HandleBookCompletionParams> {
  const HandleBookCompletionUseCase(this._bookRepository, this._quizRepository);
  final BookRepository _bookRepository;
  final BookQuizRepository _quizRepository;

  @override
  Future<Either<Failure, BookCompletionResult>> call(
    HandleBookCompletionParams params,
  ) async {
    // 1. Get current progress
    final progressResult = await _bookRepository.getReadingProgress(
      userId: params.userId,
      bookId: params.bookId,
    );

    return progressResult.fold(
      (failure) => Left(failure),
      (progress) async {
        // Already completed — no action
        if (progress.isCompleted) {
          final hasQuizResult = await _quizRepository.bookHasQuiz(params.bookId);
          final hasQuiz = hasQuizResult.fold((_) => false, (v) => v);
          return Right(BookCompletionResult(
            progress: progress,
            justCompleted: false,
            hasQuiz: hasQuiz,
          ));
        }

        // 2. Check if all chapters complete
        final chaptersResult = await _bookRepository.getChapters(params.bookId);
        final totalChapters = chaptersResult.fold((_) => 0, (c) => c.length);
        final allChaptersComplete =
            progress.completedChapterIds.length >= totalChapters && totalChapters > 0;

        if (!allChaptersComplete) {
          final hasQuizResult = await _quizRepository.bookHasQuiz(params.bookId);
          final hasQuiz = hasQuizResult.fold((_) => false, (v) => v);
          return Right(BookCompletionResult(
            progress: progress,
            justCompleted: false,
            hasQuiz: hasQuiz,
          ));
        }

        // 3. Check quiz status
        final hasQuizResult = await _quizRepository.bookHasQuiz(params.bookId);
        final hasQuiz = hasQuizResult.fold((_) => false, (v) => v);

        final quizPassed = progress.quizPassed || params.quizJustPassed;

        // Book completes when: all chapters done AND (no quiz OR quiz passed)
        final shouldComplete = !hasQuiz || quizPassed;

        if (!shouldComplete) {
          return Right(BookCompletionResult(
            progress: progress,
            justCompleted: false,
            hasQuiz: hasQuiz,
          ));
        }

        // 4. Mark as complete
        final updatedProgress = progress.copyWith(
          isCompleted: true,
          quizPassed: quizPassed,
          completedAt: DateTime.now(),
        );

        final updateResult =
            await _bookRepository.updateReadingProgress(updatedProgress);

        return updateResult.fold(
          (failure) => Left(failure),
          (saved) => Right(BookCompletionResult(
            progress: saved,
            justCompleted: true,
            hasQuiz: hasQuiz,
          )),
        );
      },
    );
  }
}
