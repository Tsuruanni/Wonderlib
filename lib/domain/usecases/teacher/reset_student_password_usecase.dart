import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class ResetStudentPasswordParams {

  const ResetStudentPasswordParams({required this.studentId});
  final String studentId;
}

/// Resets a student's password and returns the new password
class ResetStudentPasswordUseCase
    implements UseCase<String, ResetStudentPasswordParams> {

  const ResetStudentPasswordUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, String>> call(ResetStudentPasswordParams params) {
    return _repository.resetStudentPassword(params.studentId);
  }
}
