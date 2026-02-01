import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for calling Supabase Edge Functions
class EdgeFunctionService {

  EdgeFunctionService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  /// Award XP to user via edge function
  /// Returns XP result with level info and any new badges earned
  Future<AwardXPResult> awardXP({
    required String userId,
    required int amount,
    required String source,
    String? sourceId,
    String? description,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'award-xp',
        body: {
          'userId': userId,
          'amount': amount,
          'source': source,
          'sourceId': sourceId,
          'description': description,
        },
      );

      if (response.status != 200) {
        throw EdgeFunctionException(
          'Failed to award XP: ${response.data?['error'] ?? 'Unknown error'}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      return AwardXPResult.fromJson(data);
    } catch (e) {
      if (e is EdgeFunctionException) rethrow;
      throw EdgeFunctionException('Failed to call award-xp: $e');
    }
  }

  /// Check and update user streak via edge function
  /// Returns streak info and any bonus XP earned
  Future<StreakResult> checkStreak({required String userId}) async {
    try {
      final response = await _supabase.functions.invoke(
        'check-streak',
        body: {'userId': userId},
      );

      if (response.status != 200) {
        throw EdgeFunctionException(
          'Failed to check streak: ${response.data?['error'] ?? 'Unknown error'}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      return StreakResult.fromJson(data);
    } catch (e) {
      if (e is EdgeFunctionException) rethrow;
      throw EdgeFunctionException('Failed to call check-streak: $e');
    }
  }
}

/// Result of awarding XP
class AwardXPResult {

  const AwardXPResult({
    required this.success,
    this.newXp = 0,
    this.newLevel = 1,
    this.levelUp = false,
    this.newBadges = const [],
    this.error,
  });

  factory AwardXPResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final badges = (json['newBadges'] as List<dynamic>?)
            ?.map((b) => BadgeEarned.fromJson(b as Map<String, dynamic>))
            .toList() ??
        [];

    return AwardXPResult(
      success: json['success'] as bool? ?? false,
      newXp: data?['newXp'] as int? ?? 0,
      newLevel: data?['newLevel'] as int? ?? 1,
      levelUp: data?['levelUp'] as bool? ?? false,
      newBadges: badges,
      error: json['error'] as String?,
    );
  }
  final bool success;
  final int newXp;
  final int newLevel;
  final bool levelUp;
  final List<BadgeEarned> newBadges;
  final String? error;
}

/// Badge earned from XP award
class BadgeEarned {

  const BadgeEarned({
    required this.badgeId,
    required this.badgeName,
    required this.xpReward,
  });

  factory BadgeEarned.fromJson(Map<String, dynamic> json) {
    return BadgeEarned(
      badgeId: json['badgeId'] as String,
      badgeName: json['badgeName'] as String,
      xpReward: json['xpReward'] as int? ?? 0,
    );
  }
  final String badgeId;
  final String badgeName;
  final int xpReward;
}

/// Result of streak check
class StreakResult {

  const StreakResult({
    required this.success,
    this.streak = 0,
    this.longestStreak = 0,
    this.streakBroken = false,
    this.streakExtended = false,
    this.bonusXp = 0,
    this.error,
  });

  factory StreakResult.fromJson(Map<String, dynamic> json) {
    return StreakResult(
      success: json['success'] as bool? ?? false,
      streak: json['streak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      streakBroken: json['streakBroken'] as bool? ?? false,
      streakExtended: json['streakExtended'] as bool? ?? false,
      bonusXp: json['bonusXp'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
  final bool success;
  final int streak;
  final int longestStreak;
  final bool streakBroken;
  final bool streakExtended;
  final int bonusXp;
  final String? error;
}

/// Exception for edge function errors
class EdgeFunctionException implements Exception {

  EdgeFunctionException(this.message);
  final String message;

  @override
  String toString() => 'EdgeFunctionException: $message';
}
