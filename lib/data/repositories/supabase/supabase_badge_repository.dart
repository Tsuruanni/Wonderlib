import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/repositories/badge_repository.dart';
import '../../models/badge/badge_model.dart';
import '../../models/badge/user_badge_model.dart';

class SupabaseBadgeRepository implements BadgeRepository {
  SupabaseBadgeRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<Badge>>> getAllBadges() async {
    try {
      final response = await _supabase
          .from(DbTables.badges)
          .select()
          .eq('is_active', true)
          .order('category')
          .order('condition_value', ascending: true);

      final badges =
          (response as List).map((json) => BadgeModel.fromJson(json).toEntity()).toList();

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
          await _supabase.from(DbTables.badges).select().eq('id', id).single();

      return Right(BadgeModel.fromJson(response).toEntity());
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
          .from(DbTables.userBadges)
          .select('*, badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      final userBadges = (response as List)
          .map((json) => UserBadgeModel.fromJson(json).toEntity())
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
          .from(DbTables.userBadges)
          .select()
          .eq('user_id', userId)
          .eq('badge_id', badgeId)
          .maybeSingle();

      if (existing != null) {
        // Already has badge, return existing
        return Right(UserBadgeModel.fromJson(existing).toEntity());
      }

      // Award the badge
      final response = await _supabase
          .from(DbTables.userBadges)
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

      return Right(UserBadgeModel.fromJson(response).toEntity());
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
          .from(DbTables.profiles)
          .select('xp, level, current_streak, longest_streak')
          .eq('id', userId)
          .single();

      final xp = profile['xp'] as int? ?? 0;
      final level = profile['level'] as int? ?? 1;
      final currentStreak = profile['current_streak'] as int? ?? 0;

      // Get books completed
      final booksCompleted = await _supabase
          .from(DbTables.readingProgress)
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true);

      final booksCount = (booksCompleted as List).length;

      // Get vocabulary mastered
      final vocabMastered = await _supabase
          .from(DbTables.vocabularyProgress)
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'mastered');

      final vocabCount = (vocabMastered as List).length;

      // Get perfect activity scores (score == max_score)
      final allScores = await _supabase
          .from(DbTables.activityResults)
          .select('score, max_score')
          .eq('user_id', userId);

      final perfectCount = (allScores as List)
          .where((r) => r['score'] != null && r['score'] == r['max_score'])
          .length;

      // Get user's existing badges
      final existingBadges = await _supabase
          .from(DbTables.userBadges)
          .select('badge_id')
          .eq('user_id', userId);

      final earnedBadgeIds = (existingBadges as List)
          .map((b) => b['badge_id'] as String)
          .toSet();

      // Get all active badges
      final allBadges = await _supabase
          .from(DbTables.badges)
          .select()
          .eq('is_active', true);

      final earnableBadges = <Badge>[];

      for (final badgeJson in (allBadges as List)) {
        final badge = BadgeModel.fromJson(badgeJson).toEntity();

        // Skip if already earned
        if (earnedBadgeIds.contains(badge.id)) continue;

        // Check if conditions are met
        bool canEarn = false;

        switch (badge.conditionType) {
          case BadgeConditionType.xpTotal:
            canEarn = xp >= badge.conditionValue;
          case BadgeConditionType.streakDays:
            canEarn = currentStreak >= badge.conditionValue;
          case BadgeConditionType.booksCompleted:
            canEarn = booksCount >= badge.conditionValue;
          case BadgeConditionType.vocabularyLearned:
            canEarn = vocabCount >= badge.conditionValue;
          case BadgeConditionType.perfectScores:
            canEarn = perfectCount >= badge.conditionValue;
          case BadgeConditionType.levelCompleted:
            canEarn = level >= badge.conditionValue;
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
          .from(DbTables.userBadges)
          .select('*, badges(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(limit);

      final badges = (response as List)
          .where((json) => json['badges'] != null)
          .map((json) => BadgeModel.fromJson(json['badges'] as Map<String, dynamic>).toEntity())
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
      // Use atomic RPC to prevent race conditions (same as activity repo)
      await _supabase.rpc(
        RpcFunctions.awardXpTransaction,
        params: {
          'p_user_id': userId,
          'p_amount': amount,
          'p_source': reason,
          'p_source_id': null,
          'p_description': 'Badge reward',
        },
      );
    } catch (e) {
      // Log but don't fail the main operation
      debugPrint('Failed to award XP: $e');
    }
  }

}
