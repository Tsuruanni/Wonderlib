import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/repositories/badge_repository.dart';

class SupabaseBadgeRepository implements BadgeRepository {
  SupabaseBadgeRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<Badge>>> getAllBadges() async {
    try {
      final response = await _supabase
          .from('badges')
          .select()
          .eq('is_active', true)
          .order('category')
          .order('condition_value', ascending: true);

      final badges =
          (response as List).map((json) => _mapToBadge(json)).toList();

      return Right(badges);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Badge>> getBadgeById(String id) async {
    try {
      final response =
          await _supabase.from('badges').select().eq('id', id).single();

      return Right(_mapToBadge(response));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Badge not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserBadge>>> getUserBadges(String userId) async {
    try {
      final response = await _supabase
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      final userBadges = (response as List)
          .map((json) => _mapToUserBadge(json))
          .toList();

      return Right(userBadges);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserBadge>> awardBadge({
    required String userId,
    required String badgeId,
  }) async {
    try {
      // Check if user already has this badge
      final existing = await _supabase
          .from('user_badges')
          .select()
          .eq('user_id', userId)
          .eq('badge_id', badgeId)
          .maybeSingle();

      if (existing != null) {
        // Already has badge, return existing
        return Right(_mapToUserBadge(existing));
      }

      // Award the badge
      final response = await _supabase
          .from('user_badges')
          .insert({
            'user_id': userId,
            'badge_id': badgeId,
            'earned_at': DateTime.now().toIso8601String(),
          })
          .select('*, badges(*)')
          .single();

      // Award XP from badge
      final badgeXP = response['badges']?['xp_reward'] as int? ?? 0;
      if (badgeXP > 0) {
        await _awardXP(userId, badgeXP, 'badge_earned');
      }

      return Right(_mapToUserBadge(response));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Badge>>> checkEarnableBadges(
    String userId,
  ) async {
    try {
      // Get user's current stats
      final profile = await _supabase
          .from('profiles')
          .select('xp, current_streak, longest_streak')
          .eq('id', userId)
          .single();

      final xp = profile['xp'] as int? ?? 0;
      final currentStreak = profile['current_streak'] as int? ?? 0;

      // Get books completed
      final booksCompleted = await _supabase
          .from('reading_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true);

      final booksCount = (booksCompleted as List).length;

      // Get vocabulary mastered
      final vocabMastered = await _supabase
          .from('vocabulary_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'mastered');

      final vocabCount = (vocabMastered as List).length;

      // Get perfect activity scores
      final perfectScores = await _supabase
          .from('activity_results')
          .select('id')
          .eq('user_id', userId)
          .filter('score', 'eq', 'max_score'); // This might need RPC

      final perfectCount = (perfectScores as List).length;

      // Get user's existing badges
      final existingBadges = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final earnedBadgeIds = (existingBadges as List)
          .map((b) => b['badge_id'] as String)
          .toSet();

      // Get all active badges
      final allBadges = await _supabase
          .from('badges')
          .select()
          .eq('is_active', true);

      final earnableBadges = <Badge>[];

      for (final badgeJson in (allBadges as List)) {
        final badge = _mapToBadge(badgeJson);

        // Skip if already earned
        if (earnedBadgeIds.contains(badge.id)) continue;

        // Check if conditions are met
        bool canEarn = false;

        switch (badge.conditionType) {
          case BadgeConditionType.xpTotal:
            canEarn = xp >= badge.conditionValue;
            break;
          case BadgeConditionType.streakDays:
            canEarn = currentStreak >= badge.conditionValue;
            break;
          case BadgeConditionType.booksCompleted:
            canEarn = booksCount >= badge.conditionValue;
            break;
          case BadgeConditionType.vocabularyLearned:
            canEarn = vocabCount >= badge.conditionValue;
            break;
          case BadgeConditionType.perfectScores:
            canEarn = perfectCount >= badge.conditionValue;
            break;
          case BadgeConditionType.levelCompleted:
            // Check if user completed specific level
            canEarn = false; // Would need more complex logic
            break;
          case BadgeConditionType.dailyLogin:
            // Special handling needed
            canEarn = false;
            break;
        }

        if (canEarn) {
          earnableBadges.add(badge);
        }
      }

      return Right(earnableBadges);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Badge>>> getRecentlyEarned({
    required String userId,
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('user_badges')
          .select('*, badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(limit);

      final badges = (response as List)
          .map((json) => _mapToBadge(json['badges'] as Map<String, dynamic>))
          .toList();

      return Right(badges);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  Future<void> _awardXP(String userId, int amount, String reason) async {
    try {
      // Update profile XP
      final profile = await _supabase
          .from('profiles')
          .select('xp')
          .eq('id', userId)
          .single();

      final currentXP = profile['xp'] as int? ?? 0;

      await _supabase
          .from('profiles')
          .update({
            'xp': currentXP + amount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Log XP
      await _supabase.from('xp_logs').insert({
        'user_id': userId,
        'amount': amount,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log but don't fail the main operation
      // ignore: avoid_print
      print('Failed to award XP: $e');
    }
  }

  // ============================================
  // MAPPING FUNCTIONS
  // ============================================

  Badge _mapToBadge(Map<String, dynamic> data) {
    return Badge(
      id: data['id'] as String,
      name: data['name'] as String,
      slug: data['slug'] as String,
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      category: data['category'] as String?,
      conditionType: _parseConditionType(data['condition_type'] as String?),
      conditionValue: data['condition_value'] as int? ?? 0,
      xpReward: data['xp_reward'] as int? ?? 0,
      isActive: data['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  BadgeConditionType _parseConditionType(String? type) {
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

  UserBadge _mapToUserBadge(Map<String, dynamic> data) {
    final badgeData = data['badges'] as Map<String, dynamic>?;
    final badge = badgeData != null
        ? _mapToBadge(badgeData)
        : Badge(
            id: data['badge_id'] as String,
            name: 'Unknown',
            slug: 'unknown',
            conditionType: BadgeConditionType.xpTotal,
            conditionValue: 0,
            createdAt: DateTime.now(),
          );

    return UserBadge(
      id: data['id'] as String,
      odId: data['user_id'] as String,
      badgeId: data['badge_id'] as String,
      badge: badge,
      earnedAt: DateTime.parse(data['earned_at'] as String),
    );
  }
}
