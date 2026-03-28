import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/badge.dart';
import '../entities/badge_earned.dart';

abstract class BadgeRepository {
  Future<Either<Failure, List<UserBadge>>> getUserBadges(String userId);

  Future<Either<Failure, UserBadge>> awardBadge({
    required String userId,
    required String badgeId,
  });

  Future<Either<Failure, List<Badge>>> getRecentlyEarned({
    required String userId,
    int limit = 5,
  });

  Future<Either<Failure, List<BadgeEarned>>> checkAndAwardBadges(String userId);
}
