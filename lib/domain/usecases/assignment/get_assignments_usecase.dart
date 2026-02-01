import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetAssignmentsParams {
  final String teacherId;

  const GetAssignmentsParams({required this.teacherId});
}

/// Gets all assignments created by a teacher
class GetAssignmentsUseCase
    implements UseCase<List<Assignment>, GetAssignmentsParams> {
  final TeacherRepository _repository;

  const GetAssignmentsUseCase(this._repository);

  @override
  Future<Either<Failure, List<Assignment>>> call(GetAssignmentsParams params) {
    return _repository.getAssignments(params.teacherId);
  }
}
