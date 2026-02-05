import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetUserActivityResultsParams {

  const GetUserActivityResultsParams({
    required this.userId,
    this.activityId,
  });
  final String userId;
  final String? activityId;
}

class GetUserActivityResultsUseCase
    implements UseCase<List<ActivityResult>, GetUserActivityResultsParams> {

  const GetUserActivityResultsUseCase(this._repository);
  final ActivityRepository _repository;

  @override
  Future<Either<Failure, List<ActivityResult>>> call(GetUserActivityResultsParams params) {
    return _repository.getUserActivityResults(
      userId: params.userId,
      activityId: params.activityId,
    );
  }
}
