import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetBestResultParams {
  final String userId;
  final String activityId;

  const GetBestResultParams({
    required this.userId,
    required this.activityId,
  });
}

class GetBestResultUseCase implements UseCase<ActivityResult?, GetBestResultParams> {
  final ActivityRepository _repository;

  const GetBestResultUseCase(this._repository);

  @override
  Future<Either<Failure, ActivityResult?>> call(GetBestResultParams params) {
    return _repository.getBestResult(
      userId: params.userId,
      activityId: params.activityId,
    );
  }
}
