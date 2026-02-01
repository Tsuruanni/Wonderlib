import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class UpdateAssignmentProgressParams {
  final String studentId;
  final String assignmentId;
  final double progress;

  const UpdateAssignmentProgressParams({
    required this.studentId,
    required this.assignmentId,
    required this.progress,
  });
}

/// Updates assignment progress
class UpdateAssignmentProgressUseCase
    implements UseCase<void, UpdateAssignmentProgressParams> {
  final StudentAssignmentRepository _repository;

  const UpdateAssignmentProgressUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(UpdateAssignmentProgressParams params) {
    return _repository.updateAssignmentProgress(
      params.studentId,
      params.assignmentId,
      params.progress,
    );
  }
}
