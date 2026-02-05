import 'package:readeng/domain/entities/badge.dart';

/// Test fixtures for Badge-related tests
class BadgeFixtures {
  BadgeFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  static Map<String, dynamic> validBadgeJson() => {
        'id': 'badge-123',
        'name': 'First Steps',
        'slug': 'first-steps',
        'description': 'Complete your first reading session',
        'icon': 'trophy',
        'category': 'reading',
        'condition_type': 'books_completed',
        'condition_value': 1,
        'xp_reward': 50,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> xpBadgeJson() => {
        'id': 'badge-xp-100',
        'name': 'XP Hunter',
        'slug': 'xp-hunter',
        'description': 'Earn 100 XP',
        'icon': 'star',
        'category': 'xp',
        'condition_type': 'xp_total',
        'condition_value': 100,
        'xp_reward': 25,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> streakBadgeJson() => {
        'id': 'badge-streak-7',
        'name': 'Week Warrior',
        'slug': 'week-warrior',
        'description': 'Maintain a 7-day streak',
        'icon': 'fire',
        'category': 'streak',
        'condition_type': 'streak_days',
        'condition_value': 7,
        'xp_reward': 100,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> vocabularyBadgeJson() => {
        'id': 'badge-vocab-50',
        'name': 'Word Collector',
        'slug': 'word-collector',
        'description': 'Learn 50 vocabulary words',
        'icon': 'book',
        'category': 'vocabulary',
        'condition_type': 'vocabulary_learned',
        'condition_value': 50,
        'xp_reward': 75,
        'is_active': true,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> inactiveBadgeJson() => {
        'id': 'badge-inactive',
        'name': 'Legacy Badge',
        'slug': 'legacy-badge',
        'description': 'This badge is no longer available',
        'icon': 'archive',
        'category': 'legacy',
        'condition_type': 'books_completed',
        'condition_value': 100,
        'xp_reward': 500,
        'is_active': false,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> minimalBadgeJson() => {
        'id': 'badge-minimal',
        'name': 'Simple Badge',
        'slug': 'simple-badge',
        'condition_type': 'daily_login',
        'condition_value': 1,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static Map<String, dynamic> badgeJsonWithNulls() => {
        'id': 'badge-nulls',
        'name': 'Null Badge',
        'slug': 'null-badge',
        'description': null,
        'icon': null,
        'category': null,
        'condition_type': 'books_completed',
        'condition_value': 5,
        'xp_reward': null,
        'is_active': null,
        'created_at': '2024-01-01T00:00:00Z',
      };

  static List<Map<String, dynamic>> badgeListJson() => [
        validBadgeJson(),
        xpBadgeJson(),
        streakBadgeJson(),
        vocabularyBadgeJson(),
      ];

  // ============================================
  // Entity Fixtures
  // ============================================

  static Badge validBadge() => Badge(
        id: 'badge-123',
        name: 'First Steps',
        slug: 'first-steps',
        description: 'Complete your first reading session',
        icon: 'trophy',
        category: 'reading',
        conditionType: BadgeConditionType.booksCompleted,
        conditionValue: 1,
        xpReward: 50,
        isActive: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static Badge xpBadge() => Badge(
        id: 'badge-xp-100',
        name: 'XP Hunter',
        slug: 'xp-hunter',
        description: 'Earn 100 XP',
        icon: 'star',
        category: 'xp',
        conditionType: BadgeConditionType.xpTotal,
        conditionValue: 100,
        xpReward: 25,
        isActive: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static Badge streakBadge() => Badge(
        id: 'badge-streak-7',
        name: 'Week Warrior',
        slug: 'week-warrior',
        description: 'Maintain a 7-day streak',
        icon: 'fire',
        category: 'streak',
        conditionType: BadgeConditionType.streakDays,
        conditionValue: 7,
        xpReward: 100,
        isActive: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static Badge vocabularyBadge() => Badge(
        id: 'badge-vocab-50',
        name: 'Word Collector',
        slug: 'word-collector',
        description: 'Learn 50 vocabulary words',
        icon: 'book',
        category: 'vocabulary',
        conditionType: BadgeConditionType.vocabularyLearned,
        conditionValue: 50,
        xpReward: 75,
        isActive: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static Badge perfectScoreBadge() => Badge(
        id: 'badge-perfect',
        name: 'Perfectionist',
        slug: 'perfectionist',
        description: 'Get 10 perfect scores',
        icon: 'diamond',
        category: 'activity',
        conditionType: BadgeConditionType.perfectScores,
        conditionValue: 10,
        xpReward: 150,
        isActive: true,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );

  static List<Badge> badgeList() => [
        validBadge(),
        xpBadge(),
        streakBadge(),
        vocabularyBadge(),
      ];

  static List<Badge> earnableBadges() => [
        xpBadge(),
        streakBadge(),
      ];
}

/// Test fixtures for UserBadge-related tests
class UserBadgeFixtures {
  UserBadgeFixtures._();

  // ============================================
  // JSON Fixtures
  // ============================================

  static Map<String, dynamic> validUserBadgeJson() => {
        'id': 'user-badge-1',
        'od_id': 'user-123',
        'badge_id': 'badge-123',
        'badge': BadgeFixtures.validBadgeJson(),
        'earned_at': '2024-01-15T10:30:00Z',
      };

  static Map<String, dynamic> xpUserBadgeJson() => {
        'id': 'user-badge-2',
        'od_id': 'user-123',
        'badge_id': 'badge-xp-100',
        'badge': BadgeFixtures.xpBadgeJson(),
        'earned_at': '2024-01-10T08:00:00Z',
      };

  static Map<String, dynamic> streakUserBadgeJson() => {
        'id': 'user-badge-3',
        'od_id': 'user-123',
        'badge_id': 'badge-streak-7',
        'badge': BadgeFixtures.streakBadgeJson(),
        'earned_at': '2024-01-20T12:00:00Z',
      };

  static List<Map<String, dynamic>> userBadgeListJson() => [
        validUserBadgeJson(),
        xpUserBadgeJson(),
        streakUserBadgeJson(),
      ];

  // ============================================
  // Entity Fixtures
  // ============================================

  static UserBadge validUserBadge() => UserBadge(
        id: 'user-badge-1',
        odId: 'user-123',
        badgeId: 'badge-123',
        badge: BadgeFixtures.validBadge(),
        earnedAt: DateTime.parse('2024-01-15T10:30:00Z'),
      );

  static UserBadge xpUserBadge() => UserBadge(
        id: 'user-badge-2',
        odId: 'user-123',
        badgeId: 'badge-xp-100',
        badge: BadgeFixtures.xpBadge(),
        earnedAt: DateTime.parse('2024-01-10T08:00:00Z'),
      );

  static UserBadge streakUserBadge() => UserBadge(
        id: 'user-badge-3',
        odId: 'user-123',
        badgeId: 'badge-streak-7',
        badge: BadgeFixtures.streakBadge(),
        earnedAt: DateTime.parse('2024-01-20T12:00:00Z'),
      );

  static UserBadge newUserBadge() => UserBadge(
        id: 'user-badge-new',
        odId: 'user-123',
        badgeId: 'badge-vocab-50',
        badge: BadgeFixtures.vocabularyBadge(),
        earnedAt: DateTime.now(),
      );

  static List<UserBadge> userBadgeList() => [
        validUserBadge(),
        xpUserBadge(),
        streakUserBadge(),
      ];

  static List<UserBadge> recentlyEarnedList() => [
        streakUserBadge(), // Most recent
        validUserBadge(),
        xpUserBadge(),
      ];
}
