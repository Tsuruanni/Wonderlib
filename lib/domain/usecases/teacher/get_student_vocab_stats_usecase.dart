import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetStudentVocabStatsParams {

  const GetStudentVocabStatsParams({required this.studentId});
  final String studentId;
}

/// Gets student's vocabulary learning summary stats
class GetStudentVocabStatsUseCase
    implements UseCase<StudentVocabStats, GetStudentVocabStatsParams> {

  const GetStudentVocabStatsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, StudentVocabStats>> call(GetStudentVocabStatsParams params) {
    return _repository.getStudentVocabStats(params.studentId);
  }
}
