import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordProgressParams {

  const GetWordProgressParams({
    required this.userId,
    required this.wordId,
  });
  final String userId;
  final String wordId;
}

class GetWordProgressUseCase implements UseCase<VocabularyProgress, GetWordProgressParams> {

  const GetWordProgressUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, VocabularyProgress>> call(GetWordProgressParams params) {
    return _repository.getWordProgress(
      userId: params.userId,
      wordId: params.wordId,
    );
  }
}
