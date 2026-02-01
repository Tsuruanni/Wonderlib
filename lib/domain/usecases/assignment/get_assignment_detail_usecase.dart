import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetAssignmentDetailParams {
  final String assignmentId;

  const GetAssignmentDetailParams({required this.assignmentId});
}

/// Gets assignment detail with student progress
class GetAssignmentDetailUseCase
    implements UseCase<Assignment, GetAssignmentDetailParams> {
  final TeacherRepository _repository;

  const GetAssignmentDetailUseCase(this._repository);

  @override
  Future<Either<Failure, Assignment>> call(GetAssignmentDetailParams params) {
    return _repository.getAssignmentDetail(params.assignmentId);
  }
}
