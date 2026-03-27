import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity_stats.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetActivityStatsParams {

  const GetActivityStatsParams({required this.userId});
  final String userId;
}

class GetActivityStatsUseCase
    implements UseCase<ActivityStats, GetActivityStatsParams> {

  const GetActivityStatsUseCase(this._repository);
  final ActivityRepository _repository;

  @override
  Future<Either<Failure, ActivityStats>> call(GetActivityStatsParams params) {
    return _repository.getActivityStats(params.userId);
  }
}
