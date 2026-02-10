import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class ClaimDailyQuestPackParams {
  const ClaimDailyQuestPackParams({required this.userId});
  final String userId;
}

/// Claims a free card pack for completing all daily quests.
/// Returns the new unopened pack count.
class ClaimDailyQuestPackUseCase implements UseCase<int, ClaimDailyQuestPackParams> {
  const ClaimDailyQuestPackUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, int>> call(ClaimDailyQuestPackParams params) {
    return _repository.claimDailyQuestPack(params.userId);
  }
}
