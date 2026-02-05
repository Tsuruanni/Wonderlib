import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetBestResultParams {

  const GetBestResultParams({
    required this.userId,
    required this.activityId,
  });
  final String userId;
  final String activityId;
}

class GetBestResultUseCase implements UseCase<ActivityResult?, GetBestResultParams> {

  const GetBestResultUseCase(this._repository);
  final ActivityRepository _repository;

  @override
  Future<Either<Failure, ActivityResult?>> call(GetBestResultParams params) {
    return _repository.getBestResult(
      userId: params.userId,
      activityId: params.activityId,
    );
  }
}
