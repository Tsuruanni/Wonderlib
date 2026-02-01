import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class StartAssignmentParams {
  final String studentId;
  final String assignmentId;

  const StartAssignmentParams({
    required this.studentId,
    required this.assignmentId,
  });
}

/// Starts an assignment (updates status to in_progress)
class StartAssignmentUseCase implements UseCase<void, StartAssignmentParams> {
  final StudentAssignmentRepository _repository;

  const StartAssignmentUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(StartAssignmentParams params) {
    return _repository.startAssignment(params.studentId, params.assignmentId);
  }
}
