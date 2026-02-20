import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/leaderboard_entry.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';
import 'get_weekly_leaderboard_usecase.dart';

class GetUserWeeklyPositionParams {
  const GetUserWeeklyPositionParams({
    required this.userId,
    required this.scope,
    this.classId,
    this.schoolId,
    this.leagueTier,
  });

  final String userId;
  final LeaderboardScope scope;
  final String? classId;
  final String? schoolId;
  final String? leagueTier;
}

class GetUserWeeklyPositionUseCase
    implements UseCase<LeaderboardEntry, GetUserWeeklyPositionParams> {
  const GetUserWeeklyPositionUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, LeaderboardEntry>> call(
    GetUserWeeklyPositionParams params,
  ) {
    if (params.scope == LeaderboardScope.classScope) {
      if (params.classId == null) {
        return Future.value(
          const Left(ValidationFailure('Class ID required')),
        );
      }
      return _repository.getUserWeeklyClassPosition(
        userId: params.userId,
        classId: params.classId!,
      );
    } else {
      if (params.schoolId == null) {
        return Future.value(
          const Left(ValidationFailure('School ID required')),
        );
      }
      return _repository.getUserWeeklySchoolPosition(
        userId: params.userId,
        schoolId: params.schoolId!,
        leagueTier: params.leagueTier,
      );
    }
  }
}
