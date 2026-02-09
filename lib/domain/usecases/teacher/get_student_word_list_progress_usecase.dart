import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetStudentWordListProgressParams {

  const GetStudentWordListProgressParams({required this.studentId});
  final String studentId;
}

/// Gets student's word list progress (per-list breakdown)
class GetStudentWordListProgressUseCase
    implements UseCase<List<StudentWordListProgress>, GetStudentWordListProgressParams> {

  const GetStudentWordListProgressUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<StudentWordListProgress>>> call(GetStudentWordListProgressParams params) {
    return _repository.getStudentWordListProgress(params.studentId);
  }
}
