import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetUserByIdParams {

  const GetUserByIdParams({required this.userId});
  final String userId;
}

class GetUserByIdUseCase implements UseCase<User, GetUserByIdParams> {

  const GetUserByIdUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, User>> call(GetUserByIdParams params) {
    return _repository.getUserById(params.userId);
  }
}
