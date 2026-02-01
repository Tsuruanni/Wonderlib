import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetUserStatsParams {
  final String userId;

  const GetUserStatsParams({required this.userId});
}

class GetUserStatsUseCase
    implements UseCase<Map<String, dynamic>, GetUserStatsParams> {
  final UserRepository _repository;

  const GetUserStatsUseCase(this._repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(GetUserStatsParams params) {
    return _repository.getUserStats(params.userId);
  }
}
