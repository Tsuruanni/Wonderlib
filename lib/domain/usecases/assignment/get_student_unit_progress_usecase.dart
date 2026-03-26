import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/student_unit_progress_item.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetStudentUnitProgressParams {
  const GetStudentUnitProgressParams({
    required this.assignmentId,
    required this.studentId,
  });
  final String assignmentId;
  final String studentId;
}

class GetStudentUnitProgressUseCase
    implements UseCase<List<StudentUnitProgressItem>, GetStudentUnitProgressParams> {
  const GetStudentUnitProgressUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<StudentUnitProgressItem>>> call(
    GetStudentUnitProgressParams params,
  ) {
    return _repository.getStudentUnitProgress(params.assignmentId, params.studentId);
  }
}
