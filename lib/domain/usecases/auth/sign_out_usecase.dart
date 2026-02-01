import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class SignOutUseCase implements UseCase<void, NoParams> {
  final AuthRepository _repository;

  const SignOutUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) {
    return _repository.signOut();
  }
}
