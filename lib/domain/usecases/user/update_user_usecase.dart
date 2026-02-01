import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class UpdateUserParams {

  const UpdateUserParams({required this.user});
  final User user;
}

class UpdateUserUseCase implements UseCase<User, UpdateUserParams> {

  const UpdateUserUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, User>> call(UpdateUserParams params) {
    return _repository.updateUser(params.user);
  }
}
