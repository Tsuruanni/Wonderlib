import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary_unit.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetAssignedVocabularyUnitsUseCase
    implements UseCase<List<VocabularyUnit>, GetAssignedUnitsParams> {
  const GetAssignedVocabularyUnitsUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyUnit>>> call(
    GetAssignedUnitsParams params,
  ) {
    return _repository.getAssignedVocabularyUnits(params.userId);
  }
}

class GetAssignedUnitsParams {
  const GetAssignedUnitsParams({required this.userId});
  final String userId;
}
