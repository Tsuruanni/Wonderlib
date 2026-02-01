import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class SignInWithStudentNumberParams {
  final String studentNumber;
  final String password;

  const SignInWithStudentNumberParams({
    required this.studentNumber,
    required this.password,
  });
}

class SignInWithStudentNumberUseCase
    implements UseCase<User, SignInWithStudentNumberParams> {
  final AuthRepository _repository;

  const SignInWithStudentNumberUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(SignInWithStudentNumberParams params) {
    return _repository.signInWithStudentNumber(
      studentNumber: params.studentNumber,
      password: params.password,
    );
  }
}
