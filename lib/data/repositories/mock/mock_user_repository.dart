import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/vocabulary.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../datasources/local/mock_data.dart';

class MockUserRepository implements UserRepository {
  final List<User> _users = List.from(MockData.users);

  @override
  Future<Either<Failure, User>> getUserById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final user = _users.where((u) => u.id == id).firstOrNull;
    if (user == null) {
      return const Left(NotFoundFailure('User not found'));
    }
    return Right(user);
  }

  @override
  Future<Either<Failure, User>> updateUser(User user) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _users.indexWhere((u) => u.id == user.id);
    if (index == -1) {
      return const Left(NotFoundFailure('User not found'));
    }

    final updatedUser = user.copyWith(updatedAt: DateTime.now());
    _users[index] = updatedUser;
    return Right(updatedUser);
  }

  @override
  Future<Either<Failure, User>> addXP(String userId, int amount) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _users.indexWhere((u) => u.id == userId);
    if (index == -1) {
      return const Left(NotFoundFailure('User not found'));
    }

    final user = _users[index];
    final newXP = user.xp + amount;
    final newLevel = _calculateLevel(newXP);

    final updatedUser = user.copyWith(
      xp: newXP,
      level: newLevel,
      updatedAt: DateTime.now(),
    );
    _users[index] = updatedUser;
    return Right(updatedUser);
  }

  int _calculateLevel(int xp) {
    // Simple level calculation
    if (xp >= 10000) return 21;
    if (xp >= 5000) return 16;
    if (xp >= 2000) return 11;
    if (xp >= 500) return 6;
    return (xp / 100).floor() + 1;
  }

  @override
  Future<Either<Failure, User>> updateStreak(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _users.indexWhere((u) => u.id == userId);
    if (index == -1) {
      return const Left(NotFoundFailure('User not found'));
    }

    final user = _users[index];
    final now = DateTime.now();
    final lastActivity = user.lastActivityDate;

    int newStreak = user.currentStreak;
    if (lastActivity == null) {
      newStreak = 1;
    } else {
      final daysSinceLastActivity = now.difference(lastActivity).inDays;
      if (daysSinceLastActivity == 0) {
        // Same day, no change
      } else if (daysSinceLastActivity == 1) {
        // Consecutive day
        newStreak = user.currentStreak + 1;
      } else {
        // Streak broken
        newStreak = 1;
      }
    }

    final updatedUser = user.copyWith(
      currentStreak: newStreak,
      longestStreak: newStreak > user.longestStreak ? newStreak : user.longestStreak,
      lastActivityDate: now,
      updatedAt: now,
    );
    _users[index] = updatedUser;
    return Right(updatedUser);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserStats(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final user = _users.where((u) => u.id == userId).firstOrNull;
    if (user == null) {
      return const Left(NotFoundFailure('User not found'));
    }

    // Calculate stats from mock data
    final completedBooks = MockData.readingProgress
        .where((p) => p.userId == userId && p.isCompleted)
        .length;
    final totalReadingTime = MockData.readingProgress
        .where((p) => p.userId == userId)
        .fold<int>(0, (sum, p) => sum + p.totalReadingTime);
    final wordsLearned = MockData.vocabularyProgress
        .where((p) => p.userId == userId && p.status == VocabularyStatus.mastered)
        .length;

    return Right({
      'xp': user.xp,
      'level': user.level,
      'currentStreak': user.currentStreak,
      'longestStreak': user.longestStreak,
      'completedBooks': completedBooks,
      'totalReadingTimeMinutes': totalReadingTime ~/ 60,
      'wordsLearned': wordsLearned,
      'badgesEarned': MockData.userBadges.where((b) => b.odId == userId).length,
    });
  }

  @override
  Future<Either<Failure, List<User>>> getClassmates(String classId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final classmates = _users
        .where((u) => u.classId == classId && u.role.isStudent)
        .toList();

    return Right(classmates);
  }

  @override
  Future<Either<Failure, List<User>>> getLeaderboard({
    String? schoolId,
    String? classId,
    int limit = 10,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    var users = _users.where((u) => u.role.isStudent).toList();

    if (schoolId != null) {
      users = users.where((u) => u.schoolId == schoolId).toList();
    }
    if (classId != null) {
      users = users.where((u) => u.classId == classId).toList();
    }

    users.sort((a, b) => b.xp.compareTo(a.xp));
    return Right(users.take(limit).toList());
  }
}
