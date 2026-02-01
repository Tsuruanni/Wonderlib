import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class StartAssignmentParams {

  const StartAssignmentParams({
    required this.studentId,
    required this.assignmentId,
  });
  final String studentId;
  final String assignmentId;
}

/// Starts an assignment (updates status to in_progress)
class StartAssignmentUseCase implements UseCase<void, StartAssignmentParams> {

  const StartAssignmentUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, void>> call(StartAssignmentParams params) {
    return _repository.startAssignment(params.studentId, params.assignmentId);
  }
}
