import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordByIdParams {

  const GetWordByIdParams({required this.wordId});
  final String wordId;
}

class GetWordByIdUseCase implements UseCase<VocabularyWord, GetWordByIdParams> {

  const GetWordByIdUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, VocabularyWord>> call(GetWordByIdParams params) {
    return _repository.getWordById(params.wordId);
  }
}
