import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/activity_repository.dart';
import '../usecase.dart';

class GetActivitiesByChapterParams {

  const GetActivitiesByChapterParams({required this.chapterId});
  final String chapterId;
}

class GetActivitiesByChapterUseCase
    implements UseCase<List<Activity>, GetActivitiesByChapterParams> {

  const GetActivitiesByChapterUseCase(this._repository);
  final ActivityRepository _repository;

  @override
  Future<Either<Failure, List<Activity>>> call(GetActivitiesByChapterParams params) {
    return _repository.getActivitiesByChapter(params.chapterId);
  }
}
