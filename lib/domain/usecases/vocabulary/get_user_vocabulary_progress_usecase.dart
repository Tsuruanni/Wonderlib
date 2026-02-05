import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetUserVocabularyProgressParams {

  const GetUserVocabularyProgressParams({required this.userId});
  final String userId;
}

class GetUserVocabularyProgressUseCase
    implements UseCase<List<VocabularyProgress>, GetUserVocabularyProgressParams> {

  const GetUserVocabularyProgressUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyProgress>>> call(
    GetUserVocabularyProgressParams params,
  ) {
    return _repository.getUserProgress(params.userId);
  }
}
