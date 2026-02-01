import '../../../domain/entities/badge.dart';
import 'badge_model.dart';

/// Model for UserBadge entity - handles JSON serialization
class UserBadgeModel {

  const UserBadgeModel({
    required this.id,
    required this.userId,
    required this.badgeId,
    this.badgeData,
    required this.earnedAt,
  });

  factory UserBadgeModel.fromJson(Map<String, dynamic> json) {
    return UserBadgeModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      badgeId: json['badge_id'] as String,
      badgeData: json['badges'] as Map<String, dynamic>?,
      earnedAt: DateTime.parse(json['earned_at'] as String),
    );
  }

  factory UserBadgeModel.fromEntity(UserBadge entity) {
    return UserBadgeModel(
      id: entity.id,
      userId: entity.odId,
      badgeId: entity.badgeId,
      earnedAt: entity.earnedAt,
    );
  }
  final String id;
  final String userId;
  final String badgeId;
  final Map<String, dynamic>? badgeData;
  final DateTime earnedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'badge_id': badgeId,
      'earned_at': earnedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'badge_id': badgeId,
      'earned_at': earnedAt.toIso8601String(),
    };
  }

  UserBadge toEntity() {
    final badge = badgeData != null
        ? BadgeModel.fromJson(badgeData!).toEntity()
        : Badge(
            id: badgeId,
            name: 'Unknown',
            slug: 'unknown',
            conditionType: BadgeConditionType.xpTotal,
            conditionValue: 0,
            createdAt: DateTime.now(),
          );

    return UserBadge(
      id: id,
      odId: userId,
      badgeId: badgeId,
      badge: badge,
      earnedAt: earnedAt,
    );
  }
}
