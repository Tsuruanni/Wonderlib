import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/errors/failures.dart';
import '../../entities/leaderboard_entry.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

enum WeeklyLeaderboardScope { classScope, schoolScope }

class GetWeeklyLeaderboardParams {
  const GetWeeklyLeaderboardParams({
    required this.scope,
    this.classId,
    this.schoolId,
    this.limit = 10,
    this.leagueTier,
  });

  final WeeklyLeaderboardScope scope;
  final String? classId;
  final String? schoolId;
  final int limit;
  final LeagueTier? leagueTier;
}

class GetWeeklyLeaderboardUseCase
    implements UseCase<List<LeaderboardEntry>, GetWeeklyLeaderboardParams> {
  const GetWeeklyLeaderboardUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> call(
    GetWeeklyLeaderboardParams params,
  ) {
    if (params.scope == WeeklyLeaderboardScope.classScope) {
      if (params.classId == null) {
        return Future.value(
          const Left(ValidationFailure('Class ID required for class leaderboard')),
        );
      }
      return _repository.getWeeklyClassLeaderboard(
        classId: params.classId!,
        limit: params.limit,
      );
    } else {
      if (params.schoolId == null) {
        return Future.value(
          const Left(ValidationFailure('School ID required for school leaderboard')),
        );
      }
      return _repository.getWeeklySchoolLeaderboard(
        schoolId: params.schoolId!,
        limit: params.limit,
        leagueTier: params.leagueTier,
      );
    }
  }
}
