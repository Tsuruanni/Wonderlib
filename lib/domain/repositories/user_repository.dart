import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/leaderboard_entry.dart';
import '../entities/league_status.dart';
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

  /// Get league group leaderboard (ranked by weekly XP within a matchmaking group)
  Future<Either<Failure, List<LeaderboardEntry>>> getLeagueGroupLeaderboard({
    required String groupId,
    int limit = 30,
  });

  /// Get current user's league status (group membership, tier, threshold, etc.)
  Future<Either<Failure, LeagueStatus>> getUserLeagueStatus({
    required String userId,
  });
}
