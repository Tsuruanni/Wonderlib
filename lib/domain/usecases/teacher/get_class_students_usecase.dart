import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetClassStudentsParams {

  const GetClassStudentsParams({required this.classId});
  final String classId;
}

/// Gets students in a specific class
class GetClassStudentsUseCase
    implements UseCase<List<StudentSummary>, GetClassStudentsParams> {

  const GetClassStudentsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<StudentSummary>>> call(GetClassStudentsParams params) {
    return _repository.getClassStudents(params.classId);
  }
}
