import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class UpdateAssignmentProgressParams {

  const UpdateAssignmentProgressParams({
    required this.studentId,
    required this.assignmentId,
    required this.progress,
  });
  final String studentId;
  final String assignmentId;
  final double progress;
}

/// Updates assignment progress
class UpdateAssignmentProgressUseCase
    implements UseCase<void, UpdateAssignmentProgressParams> {

  const UpdateAssignmentProgressUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, void>> call(UpdateAssignmentProgressParams params) {
    return _repository.updateAssignmentProgress(
      params.studentId,
      params.assignmentId,
      params.progress,
    );
  }
}
