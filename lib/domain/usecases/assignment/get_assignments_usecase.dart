import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetAssignmentsParams {

  const GetAssignmentsParams({required this.teacherId});
  final String teacherId;
}

/// Gets all assignments created by a teacher
class GetAssignmentsUseCase
    implements UseCase<List<Assignment>, GetAssignmentsParams> {

  const GetAssignmentsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<Assignment>>> call(GetAssignmentsParams params) {
    return _repository.getAssignments(params.teacherId);
  }
}
