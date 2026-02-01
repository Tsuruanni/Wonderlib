import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class MarkChapterCompleteParams {
  final String userId;
  final String bookId;
  final String chapterId;

  const MarkChapterCompleteParams({
    required this.userId,
    required this.bookId,
    required this.chapterId,
  });
}

class MarkChapterCompleteUseCase
    implements UseCase<ReadingProgress, MarkChapterCompleteParams> {
  final BookRepository _repository;

  const MarkChapterCompleteUseCase(this._repository);

  @override
  Future<Either<Failure, ReadingProgress>> call(MarkChapterCompleteParams params) {
    return _repository.markChapterComplete(
      userId: params.userId,
      bookId: params.bookId,
      chapterId: params.chapterId,
    );
  }
}
