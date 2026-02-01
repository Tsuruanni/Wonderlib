import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetAssignmentStudentsParams {

  const GetAssignmentStudentsParams({required this.assignmentId});
  final String assignmentId;
}

/// Gets students' progress for an assignment
class GetAssignmentStudentsUseCase
    implements UseCase<List<AssignmentStudent>, GetAssignmentStudentsParams> {

  const GetAssignmentStudentsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<AssignmentStudent>>> call(GetAssignmentStudentsParams params) {
    return _repository.getAssignmentStudents(params.assignmentId);
  }
}
