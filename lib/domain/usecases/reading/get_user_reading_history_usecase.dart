import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetUserReadingHistoryParams {

  const GetUserReadingHistoryParams({required this.userId});
  final String userId;
}

class GetUserReadingHistoryUseCase
    implements UseCase<List<ReadingProgress>, GetUserReadingHistoryParams> {

  const GetUserReadingHistoryUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<ReadingProgress>>> call(
    GetUserReadingHistoryParams params,
  ) {
    return _repository.getUserReadingHistory(params.userId);
  }
}
