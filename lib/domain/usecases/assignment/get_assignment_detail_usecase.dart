import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetAssignmentDetailParams {

  const GetAssignmentDetailParams({required this.assignmentId});
  final String assignmentId;
}

/// Gets assignment detail with student progress
class GetAssignmentDetailUseCase
    implements UseCase<Assignment, GetAssignmentDetailParams> {

  const GetAssignmentDetailUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, Assignment>> call(GetAssignmentDetailParams params) {
    return _repository.getAssignmentDetail(params.assignmentId);
  }
}
