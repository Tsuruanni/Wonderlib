import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/badge.dart';

abstract class BadgeRepository {
  Future<Either<Failure, List<Badge>>> getAllBadges();

  Future<Either<Failure, Badge>> getBadgeById(String id);

  Future<Either<Failure, List<UserBadge>>> getUserBadges(String userId);

  Future<Either<Failure, UserBadge>> awardBadge({
    required String userId,
    required String badgeId,
  });

  Future<Either<Failure, List<Badge>>> checkEarnableBadges(String userId);

  Future<Either<Failure, List<Badge>>> getRecentlyEarned({
    required String userId,
    int limit = 5,
  });
}
