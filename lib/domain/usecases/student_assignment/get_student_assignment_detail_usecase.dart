import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetStudentAssignmentDetailParams {
  final String studentId;
  final String assignmentId;

  const GetStudentAssignmentDetailParams({
    required this.studentId,
    required this.assignmentId,
  });
}

/// Gets assignment detail for a student
class GetStudentAssignmentDetailUseCase
    implements UseCase<StudentAssignment, GetStudentAssignmentDetailParams> {
  final StudentAssignmentRepository _repository;

  const GetStudentAssignmentDetailUseCase(this._repository);

  @override
  Future<Either<Failure, StudentAssignment>> call(GetStudentAssignmentDetailParams params) {
    return _repository.getAssignmentDetail(params.studentId, params.assignmentId);
  }
}
