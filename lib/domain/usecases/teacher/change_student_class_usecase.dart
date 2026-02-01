import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class ChangeStudentClassParams {
  final String studentId;
  final String newClassId;

  const ChangeStudentClassParams({
    required this.studentId,
    required this.newClassId,
  });
}

/// Changes a student's class assignment
class ChangeStudentClassUseCase
    implements UseCase<void, ChangeStudentClassParams> {
  final TeacherRepository _repository;

  const ChangeStudentClassUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ChangeStudentClassParams params) {
    return _repository.updateStudentClass(
      studentId: params.studentId,
      newClassId: params.newClassId,
    );
  }
}
