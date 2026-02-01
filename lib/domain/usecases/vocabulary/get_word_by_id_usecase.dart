import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordByIdParams {
  final String wordId;

  const GetWordByIdParams({required this.wordId});
}

class GetWordByIdUseCase implements UseCase<VocabularyWord, GetWordByIdParams> {
  final VocabularyRepository _repository;

  const GetWordByIdUseCase(this._repository);

  @override
  Future<Either<Failure, VocabularyWord>> call(GetWordByIdParams params) {
    return _repository.getWordById(params.wordId);
  }
}
