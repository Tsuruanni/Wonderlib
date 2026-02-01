import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetUserByIdParams {
  final String userId;

  const GetUserByIdParams({required this.userId});
}

class GetUserByIdUseCase implements UseCase<User, GetUserByIdParams> {
  final UserRepository _repository;

  const GetUserByIdUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(GetUserByIdParams params) {
    return _repository.getUserById(params.userId);
  }
}
