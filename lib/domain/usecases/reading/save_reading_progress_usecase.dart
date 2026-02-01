import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class SaveReadingProgressParams {
  final String userId;
  final String bookId;
  final String chapterId;
  final int additionalReadingTime;

  const SaveReadingProgressParams({
    required this.userId,
    required this.bookId,
    required this.chapterId,
    required this.additionalReadingTime,
  });
}

/// Saves reading progress with accumulated reading time
class SaveReadingProgressUseCase
    implements UseCase<void, SaveReadingProgressParams> {
  final BookRepository _repository;

  const SaveReadingProgressUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SaveReadingProgressParams params) async {
    // Skip if no time to save
    if (params.additionalReadingTime <= 0) {
      return const Right(null);
    }

    // Update current chapter
    final chapterResult = await _repository.updateCurrentChapter(
      userId: params.userId,
      bookId: params.bookId,
      chapterId: params.chapterId,
    );

    if (chapterResult.isLeft()) {
      return chapterResult;
    }

    // Get current progress
    final progressResult = await _repository.getReadingProgress(
      userId: params.userId,
      bookId: params.bookId,
    );

    return progressResult.fold(
      (failure) => Left(failure),
      (progress) async {
        // Update with additional reading time
        final updatedProgress = progress.copyWith(
          totalReadingTime:
              progress.totalReadingTime + params.additionalReadingTime,
          updatedAt: DateTime.now(),
        );

        final updateResult =
            await _repository.updateReadingProgress(updatedProgress);

        return updateResult.fold(
          (failure) => Left(failure),
          (_) => const Right(null),
        );
      },
    );
  }
}
