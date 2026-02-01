import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordProgressParams {
  final String userId;
  final String wordId;

  const GetWordProgressParams({
    required this.userId,
    required this.wordId,
  });
}

class GetWordProgressUseCase implements UseCase<VocabularyProgress, GetWordProgressParams> {
  final VocabularyRepository _repository;

  const GetWordProgressUseCase(this._repository);

  @override
  Future<Either<Failure, VocabularyProgress>> call(GetWordProgressParams params) {
    return _repository.getWordProgress(
      userId: params.userId,
      wordId: params.wordId,
    );
  }
}
