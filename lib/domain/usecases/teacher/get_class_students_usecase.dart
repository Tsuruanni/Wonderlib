import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetClassStudentsParams {
  final String classId;

  const GetClassStudentsParams({required this.classId});
}

/// Gets students in a specific class
class GetClassStudentsUseCase
    implements UseCase<List<StudentSummary>, GetClassStudentsParams> {
  final TeacherRepository _repository;

  const GetClassStudentsUseCase(this._repository);

  @override
  Future<Either<Failure, List<StudentSummary>>> call(GetClassStudentsParams params) {
    return _repository.getClassStudents(params.classId);
  }
}
