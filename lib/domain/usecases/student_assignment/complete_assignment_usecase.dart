import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class CompleteAssignmentParams {

  const CompleteAssignmentParams({
    required this.studentId,
    required this.assignmentId,
    this.score,
  });
  final String studentId;
  final String assignmentId;
  final double? score;
}

/// Marks an assignment as completed
class CompleteAssignmentUseCase
    implements UseCase<void, CompleteAssignmentParams> {

  const CompleteAssignmentUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, void>> call(CompleteAssignmentParams params) {
    return _repository.completeAssignment(
      params.studentId,
      params.assignmentId,
      params.score,
    );
  }
}
