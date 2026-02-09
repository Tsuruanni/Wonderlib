import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetNodeCompletionsParams {
  const GetNodeCompletionsParams({required this.userId});
  final String userId;
}

class GetNodeCompletionsUseCase
    implements UseCase<List<NodeCompletion>, GetNodeCompletionsParams> {
  const GetNodeCompletionsUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<NodeCompletion>>> call(
    GetNodeCompletionsParams params,
  ) {
    return _repository.getNodeCompletions(params.userId);
  }
}
