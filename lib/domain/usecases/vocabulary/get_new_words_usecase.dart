import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetNewWordsParams {

  const GetNewWordsParams({
    required this.userId,
    this.limit = 10,
  });
  final String userId;
  final int limit;
}

class GetNewWordsUseCase implements UseCase<List<VocabularyWord>, GetNewWordsParams> {

  const GetNewWordsUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetNewWordsParams params) {
    return _repository.getNewWords(
      userId: params.userId,
      limit: params.limit,
    );
  }
}
