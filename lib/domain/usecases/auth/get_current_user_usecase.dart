import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class GetCurrentUserUseCase implements UseCase<User?, NoParams> {
  final AuthRepository _repository;

  const GetCurrentUserUseCase(this._repository);

  @override
  Future<Either<Failure, User?>> call(NoParams params) {
    return _repository.getCurrentUser();
  }
}
