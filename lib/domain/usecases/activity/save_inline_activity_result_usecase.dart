import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class SaveInlineActivityResultParams {
  final String userId;
  final String activityId;
  final bool isCorrect;
  final int xpEarned;

  const SaveInlineActivityResultParams({
    required this.userId,
    required this.activityId,
    required this.isCorrect,
    required this.xpEarned,
  });
}

/// Saves inline activity result and returns whether this is a NEW completion.
/// Returns `Right(true)` if newly completed, `Right(false)` if already existed.
class SaveInlineActivityResultUseCase
    implements UseCase<bool, SaveInlineActivityResultParams> {
  final BookRepository _repository;

  const SaveInlineActivityResultUseCase(this._repository);

  @override
  Future<Either<Failure, bool>> call(SaveInlineActivityResultParams params) {
    return _repository.saveInlineActivityResult(
      userId: params.userId,
      activityId: params.activityId,
      isCorrect: params.isCorrect,
      xpEarned: params.xpEarned,
    );
  }
}
