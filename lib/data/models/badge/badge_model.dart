import '../../../domain/entities/badge.dart';

/// Model for Badge entity - handles JSON serialization
class BadgeModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? category;
  final String conditionType;
  final int conditionValue;
  final int xpReward;
  final bool isActive;
  final DateTime createdAt;

  const BadgeModel({
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

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      conditionType: json['condition_type'] as String? ?? 'xp_total',
      conditionValue: json['condition_value'] as int? ?? 0,
      xpReward: json['xp_reward'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'category': category,
      'condition_type': conditionType,
      'condition_value': conditionValue,
      'xp_reward': xpReward,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Badge toEntity() {
    return Badge(
      id: id,
      name: name,
      slug: slug,
      description: description,
      icon: icon,
      category: category,
      conditionType: parseConditionType(conditionType),
      conditionValue: conditionValue,
      xpReward: xpReward,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory BadgeModel.fromEntity(Badge entity) {
    return BadgeModel(
      id: entity.id,
      name: entity.name,
      slug: entity.slug,
      description: entity.description,
      icon: entity.icon,
      category: entity.category,
      conditionType: conditionTypeToString(entity.conditionType),
      conditionValue: entity.conditionValue,
      xpReward: entity.xpReward,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  static BadgeConditionType parseConditionType(String type) {
    switch (type) {
      case 'xp_total':
        return BadgeConditionType.xpTotal;
      case 'streak_days':
        return BadgeConditionType.streakDays;
      case 'books_completed':
        return BadgeConditionType.booksCompleted;
      case 'vocabulary_learned':
        return BadgeConditionType.vocabularyLearned;
      case 'perfect_scores':
        return BadgeConditionType.perfectScores;
      case 'level_completed':
        return BadgeConditionType.levelCompleted;
      case 'daily_login':
        return BadgeConditionType.dailyLogin;
      default:
        return BadgeConditionType.xpTotal;
    }
  }

  static String conditionTypeToString(BadgeConditionType type) {
    switch (type) {
      case BadgeConditionType.xpTotal:
        return 'xp_total';
      case BadgeConditionType.streakDays:
        return 'streak_days';
      case BadgeConditionType.booksCompleted:
        return 'books_completed';
      case BadgeConditionType.vocabularyLearned:
        return 'vocabulary_learned';
      case BadgeConditionType.perfectScores:
        return 'perfect_scores';
      case BadgeConditionType.levelCompleted:
        return 'level_completed';
      case BadgeConditionType.dailyLogin:
        return 'daily_login';
    }
  }
}
