import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetActivitiesByChapterParams {
  final String chapterId;

  const GetActivitiesByChapterParams({required this.chapterId});
}

class GetActivitiesByChapterUseCase
    implements UseCase<List<Activity>, GetActivitiesByChapterParams> {
  final ActivityRepository _repository;

  const GetActivitiesByChapterUseCase(this._repository);

  @override
  Future<Either<Failure, List<Activity>>> call(GetActivitiesByChapterParams params) {
    return _repository.getActivitiesByChapter(params.chapterId);
  }
}
