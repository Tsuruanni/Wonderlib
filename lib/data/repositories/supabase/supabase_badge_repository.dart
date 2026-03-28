import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/badge_earned.dart';
import '../../../domain/repositories/badge_repository.dart';
import '../../models/badge/badge_model.dart';
import '../../models/badge/user_badge_model.dart';

class SupabaseBadgeRepository implements BadgeRepository {
  SupabaseBadgeRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

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

  @override
  Future<Either<Failure, List<BadgeEarned>>> checkAndAwardBadges(String userId) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.checkAndAwardBadges,
        params: {'p_user_id': userId},
      );

      final List rows = result is List ? result : [];
      final badges = rows.map((row) {
        final r = row as Map<String, dynamic>;
        return BadgeEarned(
          badgeId: r['badge_id'] as String,
          badgeName: r['badge_name'] as String,
          badgeIcon: r['badge_icon'] as String? ?? '🏆',
          xpReward: r['xp_reward'] as int? ?? 0,
        );
      }).toList();

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
