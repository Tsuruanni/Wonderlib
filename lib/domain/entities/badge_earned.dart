/// Represents a badge that was just earned by a user.
/// Returned by the check_and_award_badges RPC.
class BadgeEarned {
  const BadgeEarned({
    required this.badgeId,
    required this.badgeName,
    required this.badgeIcon,
    required this.xpReward,
  });

  final String badgeId;
  final String badgeName;
  final String badgeIcon;
  final int xpReward;
}
