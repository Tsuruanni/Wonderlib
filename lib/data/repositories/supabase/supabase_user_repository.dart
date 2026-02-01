import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/repositories/user_repository.dart';
import '../../models/user/user_model.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, domain.User>> getUserById(String id) async {
    try {
      final response =
          await _supabase.from('profiles').select().eq('id', id).single();

      return Right(UserModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('User not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.User>> updateUser(domain.User user) async {
    try {
      final data = {
        'first_name': user.firstName,
        'last_name': user.lastName,
        'avatar_url': user.avatarUrl,
        'settings': user.settings,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('profiles')
          .update(data)
          .eq('id', user.id)
          .select()
          .single();

      return Right(UserModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.User>> addXP(String userId, int amount) async {
    try {
      // Use stored function for atomic XP award + level calculation + logging
      await _supabase.rpc('award_xp_transaction', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_source': 'manual',
        'p_source_id': null,
        'p_description': 'XP awarded',
      });

      // Check for new badges
      await _supabase.rpc('check_and_award_badges', params: {
        'p_user_id': userId,
      });

      // Fetch updated user
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return Right(UserModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, domain.User>> updateStreak(String userId) async {
    try {
      // Use stored function for atomic streak calculation
      await _supabase.rpc('update_user_streak', params: {
        'p_user_id': userId,
      });

      // Check for new badges (including streak badges)
      await _supabase.rpc('check_and_award_badges', params: {
        'p_user_id': userId,
      });

      // Fetch updated user
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return Right(UserModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserStats(
    String userId,
  ) async {
    try {
      // Use stored function for optimized stats query
      final result = await _supabase.rpc('get_user_stats', params: {
        'p_user_id': userId,
      });

      if (result == null || (result as List).isEmpty) {
        return const Left(NotFoundFailure('User stats not found'));
      }

      final stats = result[0] as Map<String, dynamic>;

      return Right({
        'xp': stats['total_xp'] as int? ?? 0,
        'level': stats['current_level'] as int? ?? 1,
        'current_streak': stats['current_streak'] as int? ?? 0,
        'longest_streak': stats['longest_streak'] as int? ?? 0,
        'books_completed': stats['books_completed'] as int? ?? 0,
        'chapters_completed': stats['chapters_completed'] as int? ?? 0,
        'total_reading_time': stats['reading_time_total'] as int? ?? 0,
        'words_mastered': stats['words_mastered'] as int? ?? 0,
        'badges_earned': stats['badges_earned'] as int? ?? 0,
      });
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<domain.User>>> getClassmates(String classId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('class_id', classId)
          .eq('role', 'student')
          .order('first_name', ascending: true);

      final users = (response as List).map((json) => UserModel.fromJson(json).toEntity()).toList();

      return Right(users);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<domain.User>>> getLeaderboard({
    String? schoolId,
    String? classId,
    int limit = 10,
  }) async {
    try {
      var query = _supabase
          .from('profiles')
          .select()
          .eq('role', 'student');

      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }

      if (classId != null) {
        query = query.eq('class_id', classId);
      }

      final response = await query
          .order('xp', ascending: false)
          .limit(limit);

      final users = (response as List).map((json) => UserModel.fromJson(json).toEntity()).toList();

      return Right(users);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

}
