import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetCorrectAnswersTodayParams {
  const GetCorrectAnswersTodayParams({required this.userId});
  final String userId;
}

class GetCorrectAnswersTodayUseCase
    implements UseCase<int, GetCorrectAnswersTodayParams> {
  const GetCorrectAnswersTodayUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, int>> call(GetCorrectAnswersTodayParams params) {
    return _repository.getCorrectAnswersTodayCount(params.userId);
  }
}
