import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/teacher.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetSchoolBookReadingStatsParams {
  const GetSchoolBookReadingStatsParams({required this.schoolId});
  final String schoolId;
}

/// Gets per-book reading stats for a school (teacher reports)
class GetSchoolBookReadingStatsUseCase
    implements UseCase<List<BookReadingStats>, GetSchoolBookReadingStatsParams> {
  const GetSchoolBookReadingStatsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<BookReadingStats>>> call(
    GetSchoolBookReadingStatsParams params,
  ) {
    return _repository.getSchoolBookReadingStats(params.schoolId);
  }
}
