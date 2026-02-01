import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class SendPasswordResetEmailParams {

  const SendPasswordResetEmailParams({required this.email});
  final String email;
}

/// Sends password reset email to a student
class SendPasswordResetEmailUseCase
    implements UseCase<void, SendPasswordResetEmailParams> {

  const SendPasswordResetEmailUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(SendPasswordResetEmailParams params) {
    return _repository.sendPasswordResetEmail(params.email);
  }
}
