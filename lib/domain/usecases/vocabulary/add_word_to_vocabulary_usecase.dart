import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class AddWordToVocabularyParams {

  const AddWordToVocabularyParams({
    required this.userId,
    required this.wordId,
  });
  final String userId;
  final String wordId;
}

class AddWordToVocabularyUseCase
    implements UseCase<VocabularyProgress, AddWordToVocabularyParams> {

  const AddWordToVocabularyUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, VocabularyProgress>> call(AddWordToVocabularyParams params) {
    return _repository.addWordToVocabulary(
      userId: params.userId,
      wordId: params.wordId,
    );
  }
}
