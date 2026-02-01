import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class AddXPParams {
  final String userId;
  final int amount;

  const AddXPParams({
    required this.userId,
    required this.amount,
  });
}

class AddXPUseCase implements UseCase<User, AddXPParams> {
  final UserRepository _repository;

  const AddXPUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(AddXPParams params) {
    return _repository.addXP(params.userId, params.amount);
  }
}
