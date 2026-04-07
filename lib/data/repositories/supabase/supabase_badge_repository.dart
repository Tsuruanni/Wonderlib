import 'package:dartz/dartz.dart';
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

  @override
  Future<Either<Failure, List<Badge>>> getAllBadges() async {
    try {
      final response = await _supabase
          .from(DbTables.badges)
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);

      final badges = (response as List)
          .map((json) => BadgeModel.fromJson(json).toEntity())
          .toList();

      return Right(badges);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

}
