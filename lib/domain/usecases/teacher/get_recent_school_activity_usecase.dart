import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/teacher.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetRecentSchoolActivityParams {
  const GetRecentSchoolActivityParams({required this.schoolId});
  final String schoolId;
}

/// Gets recent activity feed for a school (teacher dashboard)
class GetRecentSchoolActivityUseCase
    implements UseCase<List<RecentActivity>, GetRecentSchoolActivityParams> {
  const GetRecentSchoolActivityUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<RecentActivity>>> call(
    GetRecentSchoolActivityParams params,
  ) {
    return _repository.getRecentSchoolActivity(params.schoolId);
  }
}
