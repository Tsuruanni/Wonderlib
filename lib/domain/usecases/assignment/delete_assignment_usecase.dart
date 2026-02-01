import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class DeleteAssignmentParams {
  final String assignmentId;

  const DeleteAssignmentParams({required this.assignmentId});
}

/// Deletes an assignment
class DeleteAssignmentUseCase
    implements UseCase<void, DeleteAssignmentParams> {
  final TeacherRepository _repository;

  const DeleteAssignmentUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(DeleteAssignmentParams params) {
    return _repository.deleteAssignment(params.assignmentId);
  }
}
