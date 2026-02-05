import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetVocabularyStatsParams {

  const GetVocabularyStatsParams({required this.userId});
  final String userId;
}

class GetVocabularyStatsUseCase
    implements UseCase<Map<String, int>, GetVocabularyStatsParams> {

  const GetVocabularyStatsUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, Map<String, int>>> call(GetVocabularyStatsParams params) {
    return _repository.getVocabularyStats(params.userId);
  }
}
