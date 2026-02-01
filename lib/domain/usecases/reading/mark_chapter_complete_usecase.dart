import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class MarkChapterCompleteParams {

  const MarkChapterCompleteParams({
    required this.userId,
    required this.bookId,
    required this.chapterId,
  });
  final String userId;
  final String bookId;
  final String chapterId;
}

class MarkChapterCompleteUseCase
    implements UseCase<ReadingProgress, MarkChapterCompleteParams> {

  const MarkChapterCompleteUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, ReadingProgress>> call(MarkChapterCompleteParams params) {
    return _repository.markChapterComplete(
      userId: params.userId,
      bookId: params.bookId,
      chapterId: params.chapterId,
    );
  }
}
