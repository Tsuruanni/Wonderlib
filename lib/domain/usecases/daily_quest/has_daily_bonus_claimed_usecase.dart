import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/daily_quest_repository.dart';
import '../usecase.dart';

class HasDailyBonusClaimedUseCase
    implements UseCase<bool, HasDailyBonusClaimedParams> {
  const HasDailyBonusClaimedUseCase(this._repository);

  final DailyQuestRepository _repository;

  @override
  Future<Either<Failure, bool>> call(HasDailyBonusClaimedParams params) {
    return _repository.hasDailyBonusClaimed(params.userId);
  }
}

class HasDailyBonusClaimedParams {
  const HasDailyBonusClaimedParams({required this.userId});

  final String userId;
}
