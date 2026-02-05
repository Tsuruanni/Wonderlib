import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class CompletePhaseParams {

  const CompletePhaseParams({
    required this.userId,
    required this.listId,
    required this.phase,
    this.score,
    this.total,
  });
  final String userId;
  final String listId;
  final int phase;
  final int? score;
  final int? total;
}

class CompletePhaseUseCase
    implements UseCase<UserWordListProgress, CompletePhaseParams> {

  const CompletePhaseUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, UserWordListProgress>> call(CompletePhaseParams params) {
    return _repository.completePhase(
      userId: params.userId,
      listId: params.listId,
      phase: params.phase,
      score: params.score,
      total: params.total,
    );
  }
}
