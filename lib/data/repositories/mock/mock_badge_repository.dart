import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/repositories/badge_repository.dart';
import '../../datasources/local/mock_data.dart';

class MockBadgeRepository implements BadgeRepository {
  final List<UserBadge> _userBadges = List.from(MockData.userBadges);

  @override
  Future<Either<Failure, List<Badge>>> getAllBadges() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Right(MockData.badges.where((b) => b.isActive).toList());
  }

  @override
  Future<Either<Failure, Badge>> getBadgeById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final badge = MockData.badges.where((b) => b.id == id).firstOrNull;
    if (badge == null) {
      return const Left(NotFoundFailure('Rozet bulunamadı'));
    }
    return Right(badge);
  }

  @override
  Future<Either<Failure, List<UserBadge>>> getUserBadges(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final badges = _userBadges.where((b) => b.odId == userId).toList()
      ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));

    return Right(badges);
  }

  @override
  Future<Either<Failure, UserBadge>> awardBadge({
    required String userId,
    required String badgeId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Check if already earned
    final existing = _userBadges.where(
      (b) => b.odId == userId && b.badgeId == badgeId,
    ).firstOrNull;

    if (existing != null) {
      return const Left(ValidationFailure('Bu rozet zaten kazanıldı'));
    }

    final badge = MockData.badges.where((b) => b.id == badgeId).firstOrNull;
    if (badge == null) {
      return const Left(NotFoundFailure('Rozet bulunamadı'));
    }

    final userBadge = UserBadge(
      id: 'ub-${DateTime.now().millisecondsSinceEpoch}',
      odId: userId,
      badgeId: badgeId,
      badge: badge,
      earnedAt: DateTime.now(),
    );

    _userBadges.add(userBadge);
    return Right(userBadge);
  }

  @override
  Future<Either<Failure, List<Badge>>> checkEarnableBadges(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final earnedBadgeIds = _userBadges
        .where((b) => b.odId == userId)
        .map((b) => b.badgeId)
        .toSet();

    final notEarned = MockData.badges
        .where((b) => b.isActive && !earnedBadgeIds.contains(b.id))
        .toList();

    // In real implementation, check conditions against user stats
    // For mock, just return not-earned badges
    return Right(notEarned);
  }

  @override
  Future<Either<Failure, List<Badge>>> getRecentlyEarned({
    required String userId,
    int limit = 5,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final recent = _userBadges.where((b) => b.odId == userId).toList()
      ..sort((a, b) => b.earnedAt.compareTo(a.earnedAt));

    return Right(recent.take(limit).map((ub) => ub.badge).toList());
  }
}
