import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetUserActivityResultsParams {
  final String userId;
  final String? activityId;

  const GetUserActivityResultsParams({
    required this.userId,
    this.activityId,
  });
}

class GetUserActivityResultsUseCase
    implements UseCase<List<ActivityResult>, GetUserActivityResultsParams> {
  final ActivityRepository _repository;

  const GetUserActivityResultsUseCase(this._repository);

  @override
  Future<Either<Failure, List<ActivityResult>>> call(GetUserActivityResultsParams params) {
    return _repository.getUserActivityResults(
      userId: params.userId,
      activityId: params.activityId,
    );
  }
}
