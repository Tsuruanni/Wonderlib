import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class UpdateUserParams {
  final User user;

  const UpdateUserParams({required this.user});
}

class UpdateUserUseCase implements UseCase<User, UpdateUserParams> {
  final UserRepository _repository;

  const UpdateUserUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(UpdateUserParams params) {
    return _repository.updateUser(params.user);
  }
}
