import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary_unit.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetVocabularyUnitsUseCase
    implements UseCase<List<VocabularyUnit>, NoParams> {
  const GetVocabularyUnitsUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyUnit>>> call(NoParams params) {
    return _repository.getVocabularyUnits();
  }
}
