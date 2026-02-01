import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetStudentProgressParams {
  final String studentId;

  const GetStudentProgressParams({required this.studentId});
}

/// Gets student's reading progress across all books
class GetStudentProgressUseCase
    implements UseCase<List<StudentBookProgress>, GetStudentProgressParams> {
  final TeacherRepository _repository;

  const GetStudentProgressUseCase(this._repository);

  @override
  Future<Either<Failure, List<StudentBookProgress>>> call(GetStudentProgressParams params) {
    return _repository.getStudentProgress(params.studentId);
  }
}
