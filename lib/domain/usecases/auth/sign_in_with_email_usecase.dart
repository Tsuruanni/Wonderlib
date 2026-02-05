import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class SignInWithEmailParams {

  const SignInWithEmailParams({
    required this.email,
    required this.password,
  });
  final String email;
  final String password;
}

class SignInWithEmailUseCase implements UseCase<User, SignInWithEmailParams> {

  const SignInWithEmailUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, User>> call(SignInWithEmailParams params) {
    return _repository.signInWithEmail(
      email: params.email,
      password: params.password,
    );
  }
}
