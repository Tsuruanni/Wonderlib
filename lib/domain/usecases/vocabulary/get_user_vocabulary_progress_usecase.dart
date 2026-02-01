import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetUserVocabularyProgressParams {
  final String userId;

  const GetUserVocabularyProgressParams({required this.userId});
}

class GetUserVocabularyProgressUseCase
    implements UseCase<List<VocabularyProgress>, GetUserVocabularyProgressParams> {
  final VocabularyRepository _repository;

  const GetUserVocabularyProgressUseCase(this._repository);

  @override
  Future<Either<Failure, List<VocabularyProgress>>> call(
    GetUserVocabularyProgressParams params,
  ) {
    return _repository.getUserProgress(params.userId);
  }
}
