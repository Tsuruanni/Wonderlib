import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordProgressBatchParams {

  const GetWordProgressBatchParams({
    required this.userId,
    required this.wordIds,
  });
  final String userId;
  final List<String> wordIds;
}

class GetWordProgressBatchUseCase
    implements UseCase<List<VocabularyProgress>, GetWordProgressBatchParams> {

  const GetWordProgressBatchUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyProgress>>> call(
    GetWordProgressBatchParams params,
  ) {
    return _repository.getWordProgressBatch(
      userId: params.userId,
      wordIds: params.wordIds,
    );
  }
}
