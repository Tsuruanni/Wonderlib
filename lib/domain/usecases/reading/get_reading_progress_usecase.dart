import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetReadingProgressParams {

  const GetReadingProgressParams({
    required this.userId,
    required this.bookId,
  });
  final String userId;
  final String bookId;
}

class GetReadingProgressUseCase
    implements UseCase<ReadingProgress, GetReadingProgressParams> {

  const GetReadingProgressUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, ReadingProgress>> call(GetReadingProgressParams params) {
    return _repository.getReadingProgress(
      userId: params.userId,
      bookId: params.bookId,
    );
  }
}
