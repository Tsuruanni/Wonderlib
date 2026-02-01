import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetStudentProgressParams {

  const GetStudentProgressParams({required this.studentId});
  final String studentId;
}

/// Gets student's reading progress across all books
class GetStudentProgressUseCase
    implements UseCase<List<StudentBookProgress>, GetStudentProgressParams> {

  const GetStudentProgressUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<StudentBookProgress>>> call(GetStudentProgressParams params) {
    return _repository.getStudentProgress(params.studentId);
  }
}
