import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class ResetStudentPasswordParams {
  final String studentId;

  const ResetStudentPasswordParams({required this.studentId});
}

/// Resets a student's password and returns the new password
class ResetStudentPasswordUseCase
    implements UseCase<String, ResetStudentPasswordParams> {
  final TeacherRepository _repository;

  const ResetStudentPasswordUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(ResetStudentPasswordParams params) {
    return _repository.resetStudentPassword(params.studentId);
  }
}
