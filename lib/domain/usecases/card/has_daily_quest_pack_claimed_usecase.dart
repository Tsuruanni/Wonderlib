import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class HasDailyQuestPackClaimedParams {
  const HasDailyQuestPackClaimedParams({required this.userId});
  final String userId;
}

/// Checks if the user has already claimed their daily quest pack today.
class HasDailyQuestPackClaimedUseCase implements UseCase<bool, HasDailyQuestPackClaimedParams> {
  const HasDailyQuestPackClaimedUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, bool>> call(HasDailyQuestPackClaimedParams params) {
    return _repository.hasDailyQuestPackBeenClaimed(params.userId);
  }
}
