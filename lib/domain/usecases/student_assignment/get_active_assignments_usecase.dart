import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/student_assignment.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetActiveAssignmentsParams {

  const GetActiveAssignmentsParams({required this.studentId});
  final String studentId;
}

/// Gets active (current) assignments for a student
class GetActiveAssignmentsUseCase
    implements UseCase<List<StudentAssignment>, GetActiveAssignmentsParams> {

  const GetActiveAssignmentsUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, List<StudentAssignment>>> call(GetActiveAssignmentsParams params) {
    return _repository.getActiveAssignments(params.studentId);
  }
}
