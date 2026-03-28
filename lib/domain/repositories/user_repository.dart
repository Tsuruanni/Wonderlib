import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/leaderboard_entry.dart';
import '../entities/streak_result.dart';
import '../entities/user.dart';

abstract class UserRepository {
  Future<Either<Failure, User>> getUserById(String id);

  Future<Either<Failure, User>> updateUser(User user);

  Future<Either<Failure, User>> addXP(
    String userId,
    int amount, {
    String source = 'manual',
    String? sourceId,
  });

  Future<Either<Failure, StreakResult>> updateStreak(String userId);

  Future<Either<Failure, BuyFreezeResult>> buyStreakFreeze(String userId);

  Future<Either<Failure, Map<String, dynamic>>> getUserStats(String userId);

  /// Get dates of activity for the last 7 days
  Future<Either<Failure, List<DateTime>>> getLast7DaysActivity(String userId);

  /// Get login dates for streak calendar (from daily_logins table)
  /// Returns map: date → is_freeze (true = freeze day, false = login day)
  Future<Either<Failure, Map<DateTime, bool>>> getLoginDates(String userId, DateTime from);

  Future<Either<Failure, List<User>>> getClassmates(String classId);

  /// Get total XP class leaderboard (ranked by all-time XP)
  Future<Either<Failure, List<LeaderboardEntry>>> getTotalClassLeaderboard({
    required String classId,
    int limit = 50,
  });

  /// Get total XP school leaderboard (ranked by all-time XP)
  Future<Either<Failure, List<LeaderboardEntry>>> getTotalSchoolLeaderboard({
    required String schoolId,
    int limit = 50,
  });

  /// Get current user's position in total XP class leaderboard
  Future<Either<Failure, LeaderboardEntry>> getUserClassPosition({
    required String userId,
    required String classId,
  });

  /// Get current user's position in total XP school leaderboard
  Future<Either<Failure, LeaderboardEntry>> getUserSchoolPosition({
    required String userId,
    required String schoolId,
  });

  /// Get weekly class leaderboard (ranked by weekly XP since Monday)
  Future<Either<Failure, List<LeaderboardEntry>>> getWeeklyClassLeaderboard({
    required String classId,
    int limit = 10,
  });

  /// Get weekly school leaderboard (ranked by weekly XP since Monday)
  /// When [leagueTier] is provided, ranks within that tier only.
  Future<Either<Failure, List<LeaderboardEntry>>> getWeeklySchoolLeaderboard({
    required String schoolId,
    int limit = 10,
    String? leagueTier,
  });

  /// Get current user's position in weekly class leaderboard
  Future<Either<Failure, LeaderboardEntry>> getUserWeeklyClassPosition({
    required String userId,
    required String classId,
  });

  /// Get current user's position in weekly school leaderboard
  /// When [leagueTier] is provided, ranks within that tier only.
  Future<Either<Failure, LeaderboardEntry>> getUserWeeklySchoolPosition({
    required String userId,
    required String schoolId,
    String? leagueTier,
  });
}
