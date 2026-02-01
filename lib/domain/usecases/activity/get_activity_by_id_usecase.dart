import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetActivityByIdParams {
  final String activityId;

  const GetActivityByIdParams({required this.activityId});
}

class GetActivityByIdUseCase implements UseCase<Activity, GetActivityByIdParams> {
  final ActivityRepository _repository;

  const GetActivityByIdUseCase(this._repository);

  @override
  Future<Either<Failure, Activity>> call(GetActivityByIdParams params) {
    return _repository.getActivityById(params.activityId);
  }
}
