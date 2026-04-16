import 'package:equatable/equatable.dart';
import 'badge.dart';

/// Represents a Duolingo-style achievement "track" — a grouping of tiered badges
/// that the user progresses through. Example: the Streak track contains 6 badges
/// (3, 7, 14, 30, 60, 100 days); the user is at LEVEL 3 if they've earned 3 of them.
class AchievementGroup extends Equatable {
  const AchievementGroup({
    required this.groupKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.badges,
    required this.earnedBadgeIds,
    required this.currentValue,
    required this.nextBadge,
  });

  /// Stable identifier for the group (e.g. 'streak_days', 'myth_category_completed:turkish_myths').
  final String groupKey;

  /// Display title shown in the row (e.g. "Streak", "Turkish Myths").
  final String title;

  /// Displayed under the progress bar. Usually the description of the NEXT unearned
  /// badge (e.g. "Reach a 14 day streak") or the MAX badge's description when complete.
  final String description;

  /// Emoji shown inside the icon tile.
  final String icon;

  /// All badges in this track, sorted ascending by condition_value (or tier ordinal).
  final List<Badge> badges;

  /// IDs of badges the user has earned within this track.
  final List<String> earnedBadgeIds;

  /// User's current raw stat (xp, streak days, total cards, tier ordinal, etc.).
  final int currentValue;

  /// The next badge to work toward. `null` means the user has maxed this track.
  final Badge? nextBadge;

  /// Current level = number of earned badges in this track.
  int get currentLevel => earnedBadgeIds.length;

  /// Maximum achievable level for this track (total tier count).
  int get maxLevel => badges.length;

  /// True once every tier in the track is earned.
  bool get isMaxed => nextBadge == null;

  /// Target value for the next badge (condition_value or tier ordinal). 0 when maxed.
  int get targetValue => nextBadge?.conditionValue ?? 0;

  /// Progress toward the next badge, clamped to [0.0, 1.0]. 1.0 when maxed.
  double get progress {
    if (isMaxed) return 1.0;
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0).toDouble();
  }

  @override
  List<Object?> get props => [
        groupKey,
        title,
        description,
        icon,
        badges,
        earnedBadgeIds,
        currentValue,
        nextBadge,
      ];
}
