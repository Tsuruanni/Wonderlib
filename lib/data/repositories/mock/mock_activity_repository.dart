import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../datasources/local/mock_data.dart';

class MockActivityRepository implements ActivityRepository {
  final List<ActivityResult> _results = List.from(MockData.activityResults);

  @override
  Future<Either<Failure, List<Activity>>> getActivitiesByChapter(
    String chapterId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final activities = MockData.activities
        .where((a) => a.chapterId == chapterId)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Right(activities);
  }

  @override
  Future<Either<Failure, Activity>> getActivityById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final activity = MockData.activities.where((a) => a.id == id).firstOrNull;
    if (activity == null) {
      return const Left(NotFoundFailure('Aktivite bulunamadı'));
    }
    return Right(activity);
  }

  @override
  Future<Either<Failure, ActivityResult>> submitActivityResult(
    ActivityResult result,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    _results.add(result);
    return Right(result);
  }

  @override
  Future<Either<Failure, List<ActivityResult>>> getUserActivityResults({
    required String userId,
    String? activityId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    var results = _results.where((r) => r.userId == userId).toList();

    if (activityId != null) {
      results = results.where((r) => r.activityId == activityId).toList();
    }

    results.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return Right(results);
  }

  @override
  Future<Either<Failure, ActivityResult?>> getBestResult({
    required String userId,
    required String activityId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final results = _results.where(
      (r) => r.userId == userId && r.activityId == activityId,
    ).toList();

    if (results.isEmpty) return const Right(null);

    results.sort((a, b) => b.percentage.compareTo(a.percentage));
    return Right(results.first);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getActivityStats(
    String userId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final userResults = _results.where((r) => r.userId == userId).toList();

    final totalActivities = userResults.length;
    final perfectScores = userResults.where((r) => r.isPerfect).length;
    final averageScore = userResults.isEmpty
        ? 0.0
        : userResults.fold<double>(0, (sum, r) => sum + r.percentage) /
            userResults.length;
    final totalTimeSpent =
        userResults.fold<int>(0, (sum, r) => sum + (r.timeSpent ?? 0));

    return Right({
      'totalActivities': totalActivities,
      'perfectScores': perfectScores,
      'averageScore': averageScore.round(),
      'totalTimeMinutes': totalTimeSpent ~/ 60,
    });
  }
}
