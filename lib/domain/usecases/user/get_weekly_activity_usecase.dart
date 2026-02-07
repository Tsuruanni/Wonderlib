import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetWeeklyActivityParams {

  const GetWeeklyActivityParams({required this.userId});
  final String userId;
}

class GetWeeklyActivityUseCase implements UseCase<List<DateTime>, GetWeeklyActivityParams> {

  const GetWeeklyActivityUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, List<DateTime>>> call(GetWeeklyActivityParams params) {
    return _repository.getLast7DaysActivity(params.userId);
  }
}
