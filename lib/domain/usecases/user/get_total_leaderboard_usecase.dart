import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/leaderboard_entry.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

enum TotalLeaderboardScope { classScope, schoolScope }

class GetTotalLeaderboardParams {
  const GetTotalLeaderboardParams({
    required this.scope,
    this.classId,
    this.schoolId,
    this.limit = 50,
  });

  final TotalLeaderboardScope scope;
  final String? classId;
  final String? schoolId;
  final int limit;
}

class GetTotalLeaderboardUseCase
    implements UseCase<List<LeaderboardEntry>, GetTotalLeaderboardParams> {
  const GetTotalLeaderboardUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> call(
    GetTotalLeaderboardParams params,
  ) {
    if (params.scope == TotalLeaderboardScope.classScope) {
      if (params.classId == null) {
        return Future.value(
          const Left(ValidationFailure('Class ID required for class leaderboard')),
        );
      }
      return _repository.getTotalClassLeaderboard(
        classId: params.classId!,
        limit: params.limit,
      );
    } else {
      if (params.schoolId == null) {
        return Future.value(
          const Left(ValidationFailure('School ID required for school leaderboard')),
        );
      }
      return _repository.getTotalSchoolLeaderboard(
        schoolId: params.schoolId!,
        limit: params.limit,
      );
    }
  }
}
