import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetTeacherStatsParams {
  final String teacherId;

  const GetTeacherStatsParams({required this.teacherId});
}

/// Gets dashboard statistics for a teacher
class GetTeacherStatsUseCase
    implements UseCase<TeacherStats, GetTeacherStatsParams> {
  final TeacherRepository _repository;

  const GetTeacherStatsUseCase(this._repository);

  @override
  Future<Either<Failure, TeacherStats>> call(GetTeacherStatsParams params) {
    return _repository.getTeacherStats(params.teacherId);
  }
}
