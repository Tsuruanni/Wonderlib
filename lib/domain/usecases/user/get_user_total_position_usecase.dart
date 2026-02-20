import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/leaderboard_entry.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';
import 'get_total_leaderboard_usecase.dart';

class GetUserTotalPositionParams {
  const GetUserTotalPositionParams({
    required this.userId,
    required this.scope,
    this.classId,
    this.schoolId,
  });

  final String userId;
  final TotalLeaderboardScope scope;
  final String? classId;
  final String? schoolId;
}

class GetUserTotalPositionUseCase
    implements UseCase<LeaderboardEntry, GetUserTotalPositionParams> {
  const GetUserTotalPositionUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, LeaderboardEntry>> call(
    GetUserTotalPositionParams params,
  ) {
    if (params.scope == TotalLeaderboardScope.classScope) {
      if (params.classId == null) {
        return Future.value(
          const Left(ValidationFailure('Class ID required')),
        );
      }
      return _repository.getUserClassPosition(
        userId: params.userId,
        classId: params.classId!,
      );
    } else {
      if (params.schoolId == null) {
        return Future.value(
          const Left(ValidationFailure('School ID required')),
        );
      }
      return _repository.getUserSchoolPosition(
        userId: params.userId,
        schoolId: params.schoolId!,
      );
    }
  }
}
