import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class DeleteAssignmentParams {

  const DeleteAssignmentParams({required this.assignmentId});
  final String assignmentId;
}

/// Deletes an assignment
class DeleteAssignmentUseCase
    implements UseCase<void, DeleteAssignmentParams> {

  const DeleteAssignmentUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(DeleteAssignmentParams params) {
    return _repository.deleteAssignment(params.assignmentId);
  }
}
