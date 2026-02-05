import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class SubmitActivityResultParams {

  const SubmitActivityResultParams({required this.result});
  final ActivityResult result;
}

class SubmitActivityResultUseCase
    implements UseCase<ActivityResult, SubmitActivityResultParams> {

  const SubmitActivityResultUseCase(this._repository);
  final ActivityRepository _repository;

  @override
  Future<Either<Failure, ActivityResult>> call(SubmitActivityResultParams params) {
    return _repository.submitActivityResult(params.result);
  }
}
