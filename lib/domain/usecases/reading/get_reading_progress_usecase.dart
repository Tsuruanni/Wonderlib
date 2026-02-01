import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetReadingProgressParams {
  final String userId;
  final String bookId;

  const GetReadingProgressParams({
    required this.userId,
    required this.bookId,
  });
}

class GetReadingProgressUseCase
    implements UseCase<ReadingProgress, GetReadingProgressParams> {
  final BookRepository _repository;

  const GetReadingProgressUseCase(this._repository);

  @override
  Future<Either<Failure, ReadingProgress>> call(GetReadingProgressParams params) {
    return _repository.getReadingProgress(
      userId: params.userId,
      bookId: params.bookId,
    );
  }
}
