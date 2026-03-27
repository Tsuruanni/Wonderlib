import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class SaveDailyReviewPositionParams {
  const SaveDailyReviewPositionParams({
    required this.sessionId,
    required this.pathPosition,
  });

  final String sessionId;
  final int pathPosition;
}

class SaveDailyReviewPositionUseCase
    implements UseCase<void, SaveDailyReviewPositionParams> {
  const SaveDailyReviewPositionUseCase(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, void>> call(SaveDailyReviewPositionParams params) {
    return _repository.saveDailyReviewPosition(
      sessionId: params.sessionId,
      pathPosition: params.pathPosition,
    );
  }
}
