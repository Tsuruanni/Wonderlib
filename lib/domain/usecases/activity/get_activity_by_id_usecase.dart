import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetActivityByIdParams {

  const GetActivityByIdParams({required this.activityId});
  final String activityId;
}

class GetActivityByIdUseCase implements UseCase<Activity, GetActivityByIdParams> {

  const GetActivityByIdUseCase(this._repository);
  final ActivityRepository _repository;

  @override
  Future<Either<Failure, Activity>> call(GetActivityByIdParams params) {
    return _repository.getActivityById(params.activityId);
  }
}
