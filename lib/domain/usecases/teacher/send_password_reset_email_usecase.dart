import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class SendPasswordResetEmailParams {
  final String email;

  const SendPasswordResetEmailParams({required this.email});
}

/// Sends password reset email to a student
class SendPasswordResetEmailUseCase
    implements UseCase<void, SendPasswordResetEmailParams> {
  final TeacherRepository _repository;

  const SendPasswordResetEmailUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SendPasswordResetEmailParams params) {
    return _repository.sendPasswordResetEmail(params.email);
  }
}
