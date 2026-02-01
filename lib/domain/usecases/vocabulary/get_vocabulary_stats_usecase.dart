import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetVocabularyStatsParams {
  final String userId;

  const GetVocabularyStatsParams({required this.userId});
}

class GetVocabularyStatsUseCase
    implements UseCase<Map<String, int>, GetVocabularyStatsParams> {
  final VocabularyRepository _repository;

  const GetVocabularyStatsUseCase(this._repository);

  @override
  Future<Either<Failure, Map<String, int>>> call(GetVocabularyStatsParams params) {
    return _repository.getVocabularyStats(params.userId);
  }
}
