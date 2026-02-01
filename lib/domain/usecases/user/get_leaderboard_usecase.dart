import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetLeaderboardParams {

  const GetLeaderboardParams({
    this.schoolId,
    this.classId,
    this.limit = 10,
  });
  final String? schoolId;
  final String? classId;
  final int limit;
}

class GetLeaderboardUseCase
    implements UseCase<List<User>, GetLeaderboardParams> {

  const GetLeaderboardUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, List<User>>> call(GetLeaderboardParams params) {
    return _repository.getLeaderboard(
      schoolId: params.schoolId,
      classId: params.classId,
      limit: params.limit,
    );
  }
}
