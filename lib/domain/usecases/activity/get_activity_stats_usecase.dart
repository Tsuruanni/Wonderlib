import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetActivityStatsParams {
  final String userId;

  const GetActivityStatsParams({required this.userId});
}

class GetActivityStatsUseCase
    implements UseCase<Map<String, dynamic>, GetActivityStatsParams> {
  final ActivityRepository _repository;

  const GetActivityStatsUseCase(this._repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(GetActivityStatsParams params) {
    return _repository.getActivityStats(params.userId);
  }
}
