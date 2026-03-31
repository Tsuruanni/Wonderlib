import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/leaderboard_entry.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetLeagueGroupLeaderboardParams {
  const GetLeagueGroupLeaderboardParams({
    required this.groupId,
    this.limit = 30,
  });

  final String groupId;
  final int limit;
}

class GetLeagueGroupLeaderboardUseCase
    implements UseCase<List<LeaderboardEntry>, GetLeagueGroupLeaderboardParams> {
  const GetLeagueGroupLeaderboardUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> call(
    GetLeagueGroupLeaderboardParams params,
  ) {
    return _repository.getLeagueGroupLeaderboard(
      groupId: params.groupId,
      limit: params.limit,
    );
  }
}
