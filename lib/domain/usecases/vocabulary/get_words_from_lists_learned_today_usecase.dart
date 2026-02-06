import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordsFromListsLearnedTodayParams {
  const GetWordsFromListsLearnedTodayParams({required this.userId});
  final String userId;
}

class GetWordsFromListsLearnedTodayUseCase
    implements UseCase<int, GetWordsFromListsLearnedTodayParams> {
  const GetWordsFromListsLearnedTodayUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, int>> call(GetWordsFromListsLearnedTodayParams params) {
    return _repository.getWordsLearnedFromListsTodayCount(params.userId);
  }
}
