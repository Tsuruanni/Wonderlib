import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class ChangeStudentClassParams {

  const ChangeStudentClassParams({
    required this.studentId,
    required this.newClassId,
  });
  final String studentId;
  final String newClassId;
}

/// Changes a student's class assignment
class ChangeStudentClassUseCase
    implements UseCase<void, ChangeStudentClassParams> {

  const ChangeStudentClassUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(ChangeStudentClassParams params) {
    return _repository.updateStudentClass(
      studentId: params.studentId,
      newClassId: params.newClassId,
    );
  }
}
