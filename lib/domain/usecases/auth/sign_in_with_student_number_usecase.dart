import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class SignInWithStudentNumberParams {

  const SignInWithStudentNumberParams({
    required this.studentNumber,
    required this.password,
  });
  final String studentNumber;
  final String password;
}

class SignInWithStudentNumberUseCase
    implements UseCase<User, SignInWithStudentNumberParams> {

  const SignInWithStudentNumberUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, User>> call(SignInWithStudentNumberParams params) {
    return _repository.signInWithStudentNumber(
      studentNumber: params.studentNumber,
      password: params.password,
    );
  }
}
