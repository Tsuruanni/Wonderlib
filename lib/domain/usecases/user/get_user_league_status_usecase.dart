import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/league_status.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetUserLeagueStatusParams {
  const GetUserLeagueStatusParams({required this.userId});
  final String userId;
}

class GetUserLeagueStatusUseCase
    implements UseCase<LeagueStatus, GetUserLeagueStatusParams> {
  const GetUserLeagueStatusUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, LeagueStatus>> call(
    GetUserLeagueStatusParams params,
  ) {
    return _repository.getUserLeagueStatus(userId: params.userId);
  }
}
