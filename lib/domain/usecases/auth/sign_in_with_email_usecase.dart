import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class SignInWithEmailParams {
  final String email;
  final String password;

  const SignInWithEmailParams({
    required this.email,
    required this.password,
  });
}

class SignInWithEmailUseCase implements UseCase<User, SignInWithEmailParams> {
  final AuthRepository _repository;

  const SignInWithEmailUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(SignInWithEmailParams params) {
    return _repository.signInWithEmail(
      email: params.email,
      password: params.password,
    );
  }
}
