import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetSchoolStudentsForTeacherParams {
  const GetSchoolStudentsForTeacherParams({required this.schoolId});
  final String schoolId;
}

/// Gets all students in a school sorted by XP (teacher leaderboard report).
/// Eliminates N+1 by fetching all students in one query instead of per-class.
class GetSchoolStudentsForTeacherUseCase
    implements UseCase<List<StudentSummary>, GetSchoolStudentsForTeacherParams> {
  const GetSchoolStudentsForTeacherUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<StudentSummary>>> call(
    GetSchoolStudentsForTeacherParams params,
  ) {
    return _repository.getSchoolStudentsForTeacher(params.schoolId);
  }
}
