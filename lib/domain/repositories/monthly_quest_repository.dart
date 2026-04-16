import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/monthly_quest.dart';

abstract class MonthlyQuestRepository {
  Future<Either<Failure, List<MonthlyQuestProgress>>> getMonthlyQuestProgress(String userId);
}
