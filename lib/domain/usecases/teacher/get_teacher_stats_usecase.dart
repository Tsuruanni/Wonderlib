import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetTeacherStatsParams {

  const GetTeacherStatsParams({required this.teacherId});
  final String teacherId;
}

/// Gets dashboard statistics for a teacher
class GetTeacherStatsUseCase
    implements UseCase<TeacherStats, GetTeacherStatsParams> {

  const GetTeacherStatsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, TeacherStats>> call(GetTeacherStatsParams params) {
    return _repository.getTeacherStats(params.teacherId);
  }
}
