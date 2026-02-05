import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetWordsReadTodayParams {
  const GetWordsReadTodayParams({required this.userId});
  final String userId;
}

class GetWordsReadTodayUseCase
    implements UseCase<int, GetWordsReadTodayParams> {
  const GetWordsReadTodayUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, int>> call(GetWordsReadTodayParams params) {
    return _repository.getWordsReadTodayCount(params.userId);
  }
}
