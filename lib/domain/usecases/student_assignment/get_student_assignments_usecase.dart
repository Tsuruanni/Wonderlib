import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/student_assignment.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetStudentAssignmentsParams {

  const GetStudentAssignmentsParams({required this.studentId});
  final String studentId;
}

/// Gets all assignments for a student
class GetStudentAssignmentsUseCase
    implements UseCase<List<StudentAssignment>, GetStudentAssignmentsParams> {

  const GetStudentAssignmentsUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, List<StudentAssignment>>> call(GetStudentAssignmentsParams params) {
    return _repository.getStudentAssignments(params.studentId);
  }
}
