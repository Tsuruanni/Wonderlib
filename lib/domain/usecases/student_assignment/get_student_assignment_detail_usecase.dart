import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetStudentAssignmentDetailParams {

  const GetStudentAssignmentDetailParams({
    required this.studentId,
    required this.assignmentId,
  });
  final String studentId;
  final String assignmentId;
}

/// Gets assignment detail for a student
class GetStudentAssignmentDetailUseCase
    implements UseCase<StudentAssignment, GetStudentAssignmentDetailParams> {

  const GetStudentAssignmentDetailUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, StudentAssignment>> call(GetStudentAssignmentDetailParams params) {
    return _repository.getAssignmentDetail(params.studentId, params.assignmentId);
  }
}
