import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/daily_quest.dart';

abstract class DailyQuestRepository {
  Future<Either<Failure, List<DailyQuestProgress>>> getDailyQuestProgress(String userId);
  Future<Either<Failure, DailyBonusResult>> claimDailyBonus(String userId);
  Future<Either<Failure, bool>> hasDailyBonusClaimed(String userId);
}
