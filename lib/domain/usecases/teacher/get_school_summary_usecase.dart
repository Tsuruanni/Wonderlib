import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetSchoolSummaryParams {
  const GetSchoolSummaryParams({required this.schoolId});
  final String schoolId;
}

/// Gets aggregate stats for the teacher's own school (used in "My School" card).
class GetSchoolSummaryUseCase
    implements UseCase<SchoolSummary, GetSchoolSummaryParams> {
  const GetSchoolSummaryUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, SchoolSummary>> call(
    GetSchoolSummaryParams params,
  ) {
    return _repository.getSchoolSummary(params.schoolId);
  }
}
