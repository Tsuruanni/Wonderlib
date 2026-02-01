import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetNewWordsParams {
  final String userId;
  final int limit;

  const GetNewWordsParams({
    required this.userId,
    this.limit = 10,
  });
}

class GetNewWordsUseCase implements UseCase<List<VocabularyWord>, GetNewWordsParams> {
  final VocabularyRepository _repository;

  const GetNewWordsUseCase(this._repository);

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetNewWordsParams params) {
    return _repository.getNewWords(
      userId: params.userId,
      limit: params.limit,
    );
  }
}
