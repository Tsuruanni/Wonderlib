import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetUserReadingHistoryParams {
  final String userId;

  const GetUserReadingHistoryParams({required this.userId});
}

class GetUserReadingHistoryUseCase
    implements UseCase<List<ReadingProgress>, GetUserReadingHistoryParams> {
  final BookRepository _repository;

  const GetUserReadingHistoryUseCase(this._repository);

  @override
  Future<Either<Failure, List<ReadingProgress>>> call(
    GetUserReadingHistoryParams params,
  ) {
    return _repository.getUserReadingHistory(params.userId);
  }
}
