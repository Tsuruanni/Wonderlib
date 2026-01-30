import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/user.dart';

abstract class UserRepository {
  Future<Either<Failure, User>> getUserById(String id);

  Future<Either<Failure, User>> updateUser(User user);

  Future<Either<Failure, User>> addXP(String userId, int amount);

  Future<Either<Failure, User>> updateStreak(String userId);

  Future<Either<Failure, Map<String, dynamic>>> getUserStats(String userId);

  Future<Either<Failure, List<User>>> getClassmates(String classId);

  Future<Either<Failure, List<User>>> getLeaderboard({
    String? schoolId,
    String? classId,
    int limit = 10,
  });
}
