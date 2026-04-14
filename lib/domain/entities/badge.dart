import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

export 'package:owlio_shared/src/enums/badge_condition_type.dart';

class Badge extends Equatable {

  const Badge({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.category,
    required this.conditionType,
    required this.conditionValue,
    this.conditionParam,
    this.xpReward = 0,
    this.isActive = true,
    required this.createdAt,
  });
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? category;
  final BadgeConditionType conditionType;
  final int conditionValue;
  final String? conditionParam;
  final int xpReward;
  final bool isActive;
  final DateTime createdAt;

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
        conditionParam,
        xpReward,
        isActive,
        createdAt,
      ];
}

class UserBadge extends Equatable {

  const UserBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.badge,
    required this.earnedAt,
  });
  final String id;
  final String userId;
  final String badgeId;
  final Badge badge;
  final DateTime earnedAt;

  @override
  List<Object?> get props => [id, userId, badgeId, badge, earnedAt];
}
