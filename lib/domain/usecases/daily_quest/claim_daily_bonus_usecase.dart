import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/daily_quest.dart';
import '../../repositories/daily_quest_repository.dart';
import '../usecase.dart';

class ClaimDailyBonusUseCase
    implements UseCase<DailyBonusResult, ClaimDailyBonusParams> {
  const ClaimDailyBonusUseCase(this._repository);

  final DailyQuestRepository _repository;

  @override
  Future<Either<Failure, DailyBonusResult>> call(ClaimDailyBonusParams params) {
    return _repository.claimDailyBonus(params.userId);
  }
}

class ClaimDailyBonusParams {
  const ClaimDailyBonusParams({required this.userId});

  final String userId;
}
