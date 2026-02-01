import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetStudentAssignmentsParams {
  final String studentId;

  const GetStudentAssignmentsParams({required this.studentId});
}

/// Gets all assignments for a student
class GetStudentAssignmentsUseCase
    implements UseCase<List<StudentAssignment>, GetStudentAssignmentsParams> {
  final StudentAssignmentRepository _repository;

  const GetStudentAssignmentsUseCase(this._repository);

  @override
  Future<Either<Failure, List<StudentAssignment>>> call(GetStudentAssignmentsParams params) {
    return _repository.getStudentAssignments(params.studentId);
  }
}
