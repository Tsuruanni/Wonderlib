import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordsLearnedTodayParams {
  const GetWordsLearnedTodayParams({required this.userId});
  final String userId;
}

class GetWordsLearnedTodayUseCase
    implements UseCase<int, GetWordsLearnedTodayParams> {
  const GetWordsLearnedTodayUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, int>> call(GetWordsLearnedTodayParams params) {
    return _repository.getWordsLearnedTodayCount(params.userId);
  }
}
