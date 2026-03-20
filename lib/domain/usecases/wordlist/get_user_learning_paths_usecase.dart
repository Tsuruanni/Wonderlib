import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/learning_path.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetUserLearningPathsUseCase
    implements UseCase<List<LearningPath>, GetUserLearningPathsParams> {
  const GetUserLearningPathsUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, List<LearningPath>>> call(
    GetUserLearningPathsParams params,
  ) {
    return _repository.getUserLearningPaths(params.userId);
  }
}

class GetUserLearningPathsParams {
  const GetUserLearningPathsParams({required this.userId});
  final String userId;
}
