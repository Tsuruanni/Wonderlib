import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class AddWordToVocabularyParams {
  final String userId;
  final String wordId;

  const AddWordToVocabularyParams({
    required this.userId,
    required this.wordId,
  });
}

class AddWordToVocabularyUseCase
    implements UseCase<VocabularyProgress, AddWordToVocabularyParams> {
  final VocabularyRepository _repository;

  const AddWordToVocabularyUseCase(this._repository);

  @override
  Future<Either<Failure, VocabularyProgress>> call(AddWordToVocabularyParams params) {
    return _repository.addWordToVocabulary(
      userId: params.userId,
      wordId: params.wordId,
    );
  }
}
