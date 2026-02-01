import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetActiveAssignmentsParams {
  final String studentId;

  const GetActiveAssignmentsParams({required this.studentId});
}

/// Gets active (current) assignments for a student
class GetActiveAssignmentsUseCase
    implements UseCase<List<StudentAssignment>, GetActiveAssignmentsParams> {
  final StudentAssignmentRepository _repository;

  const GetActiveAssignmentsUseCase(this._repository);

  @override
  Future<Either<Failure, List<StudentAssignment>>> call(GetActiveAssignmentsParams params) {
    return _repository.getActiveAssignments(params.studentId);
  }
}
