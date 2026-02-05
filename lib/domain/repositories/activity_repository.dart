import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/activity.dart';

abstract class ActivityRepository {
  Future<Either<Failure, List<Activity>>> getActivitiesByChapter(
    String chapterId,
  );

  Future<Either<Failure, Activity>> getActivityById(String id);

  Future<Either<Failure, ActivityResult>> submitActivityResult(
    ActivityResult result,
  );

  Future<Either<Failure, List<ActivityResult>>> getUserActivityResults({
    required String userId,
    String? activityId,
  });

  Future<Either<Failure, ActivityResult?>> getBestResult({
    required String userId,
    required String activityId,
  });

  Future<Either<Failure, Map<String, dynamic>>> getActivityStats(String userId);
}
