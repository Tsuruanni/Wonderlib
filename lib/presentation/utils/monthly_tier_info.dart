import '../../domain/entities/badge.dart';

/// Compact summary of the user's progress through a monthly quest's tier
/// badges (Bronze 1×, Silver 3×, Gold 5× …). Computed from the global
/// badge list + user badges + the quest's `completion_count`.
class MonthlyTierInfo {
  const MonthlyTierInfo({
    required this.label,
    required this.allEarned,
  });

  /// Human-readable status line for the quest card pill.
  final String label;

  /// True once every tier badge for this quest has been earned.
  final bool allEarned;
}

/// Computes [MonthlyTierInfo] for a specific quest given all badges, the
/// user's earned badge ids, and the user's total completion count across
/// all months. Returns null when no tier badges are configured.
MonthlyTierInfo? monthlyTierInfo(
  List<Badge> allBadges,
  List<UserBadge> userBadges,
  String questId,
  int completionCount,
) {
  final tiers = allBadges
      .where((b) =>
          b.conditionType == BadgeConditionType.monthlyQuestCompleted &&
          b.conditionParam == questId &&
          b.isActive,)
      .toList()
    ..sort((a, b) => a.conditionValue.compareTo(b.conditionValue));

  if (tiers.isEmpty) return null;

  final earnedIds = userBadges.map((ub) => ub.badgeId).toSet();
  final earnedTiers =
      tiers.where((b) => earnedIds.contains(b.id)).toList(growable: false);
  final allEarned = earnedTiers.length == tiers.length;

  if (allEarned) {
    return const MonthlyTierInfo(
      label: 'All tiers earned!',
      allEarned: true,
    );
  }

  // Next tier = first tier whose threshold > completionCount.
  final nextTier = tiers.firstWhere(
    (b) => b.conditionValue > completionCount,
    orElse: () => tiers.last,
  );
  final needed = nextTier.conditionValue - completionCount;

  if (earnedTiers.isEmpty) {
    return MonthlyTierInfo(
      label: '$needed more to earn ${nextTier.name}',
      allEarned: false,
    );
  }

  final latest = earnedTiers.last;
  return MonthlyTierInfo(
    label: '${latest.name} earned · $needed more for ${nextTier.name}',
    allEarned: false,
  );
}
