import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary_session.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetSessionHistoryParams {
  const GetSessionHistoryParams({
    required this.userId,
    required this.wordListId,
  });

  final String userId;
  final String wordListId;
}

class GetSessionHistoryUseCase
    implements
        UseCase<List<VocabularySessionResult>, GetSessionHistoryParams> {
  const GetSessionHistoryUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, List<VocabularySessionResult>>> call(
    GetSessionHistoryParams params,
  ) {
    return _repository.getSessionHistory(
      userId: params.userId,
      wordListId: params.wordListId,
    );
  }
}
