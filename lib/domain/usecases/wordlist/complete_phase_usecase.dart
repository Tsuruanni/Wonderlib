import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class CompletePhaseParams {
  final String userId;
  final String listId;
  final int phase;
  final int? score;
  final int? total;

  const CompletePhaseParams({
    required this.userId,
    required this.listId,
    required this.phase,
    this.score,
    this.total,
  });
}

class CompletePhaseUseCase
    implements UseCase<UserWordListProgress, CompletePhaseParams> {
  final WordListRepository _repository;

  const CompletePhaseUseCase(this._repository);

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
