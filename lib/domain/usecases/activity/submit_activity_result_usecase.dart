import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class SubmitActivityResultParams {
  final ActivityResult result;

  const SubmitActivityResultParams({required this.result});
}

class SubmitActivityResultUseCase
    implements UseCase<ActivityResult, SubmitActivityResultParams> {
  final ActivityRepository _repository;

  const SubmitActivityResultUseCase(this._repository);

  @override
  Future<Either<Failure, ActivityResult>> call(SubmitActivityResultParams params) {
    return _repository.submitActivityResult(params.result);
  }
}
