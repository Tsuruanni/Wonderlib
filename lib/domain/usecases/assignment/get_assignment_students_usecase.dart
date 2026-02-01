import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetAssignmentStudentsParams {
  final String assignmentId;

  const GetAssignmentStudentsParams({required this.assignmentId});
}

/// Gets students' progress for an assignment
class GetAssignmentStudentsUseCase
    implements UseCase<List<AssignmentStudent>, GetAssignmentStudentsParams> {
  final TeacherRepository _repository;

  const GetAssignmentStudentsUseCase(this._repository);

  @override
  Future<Either<Failure, List<AssignmentStudent>>> call(GetAssignmentStudentsParams params) {
    return _repository.getAssignmentStudents(params.assignmentId);
  }
}
