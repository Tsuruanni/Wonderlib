import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetLoginDatesParams {
  const GetLoginDatesParams({required this.userId, required this.from});
  final String userId;
  final DateTime from;
}

class GetLoginDatesUseCase implements UseCase<Map<DateTime, bool>, GetLoginDatesParams> {
  const GetLoginDatesUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, Map<DateTime, bool>>> call(GetLoginDatesParams params) {
    return _repository.getLoginDates(params.userId, params.from);
  }
}
