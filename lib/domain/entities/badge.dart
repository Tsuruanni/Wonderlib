import 'package:equatable/equatable.dart';

enum BadgeConditionType {
  xpTotal,
  streakDays,
  booksCompleted,
  vocabularyLearned,
  perfectScores,
  levelCompleted,
  dailyLogin,
}

class Badge extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? category;
  final BadgeConditionType conditionType;
  final int conditionValue;
  final int xpReward;
  final bool isActive;
  final DateTime createdAt;

  const Badge({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.category,
    required this.conditionType,
    required this.conditionValue,
    this.xpReward = 0,
    this.isActive = true,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        icon,
        category,
        conditionType,
        conditionValue,
        xpReward,
        isActive,
        createdAt,
      ];
}

class UserBadge extends Equatable {
  final String id;
  final String odId;
  final String badgeId;
  final Badge badge;
  final DateTime earnedAt;

  const UserBadge({
    required this.id,
    required this.odId,
    required this.badgeId,
    required this.badge,
    required this.earnedAt,
  });

  @override
  List<Object?> get props => [id, odId, badgeId, badge, earnedAt];
}
