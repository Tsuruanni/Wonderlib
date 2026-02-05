import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetUserStatsParams {

  const GetUserStatsParams({required this.userId});
  final String userId;
}

class GetUserStatsUseCase
    implements UseCase<Map<String, dynamic>, GetUserStatsParams> {

  const GetUserStatsUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(GetUserStatsParams params) {
    return _repository.getUserStats(params.userId);
  }
}
