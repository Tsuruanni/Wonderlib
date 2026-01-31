import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/repositories/user_repository.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, domain.User>> getUserById(String id) async {
    try {
      final response =
          await _supabase.from('profiles').select().eq('id', id).single();

      return Right(_mapToUser(response));
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

      return Right(_mapToUser(response));
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

      return Right(_mapToUser(response));
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

      // Fetch updated user
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return Right(_mapToUser(response));
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

      final users = (response as List).map((json) => _mapToUser(json)).toList();

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

      final users = (response as List).map((json) => _mapToUser(json)).toList();

      return Right(users);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  int _calculateLevel(int xp) {
    // Level thresholds based on app_constants.dart UserLevel
    if (xp >= 50000) return 10; // Diamond
    if (xp >= 25000) return 9;
    if (xp >= 15000) return 8; // Platinum
    if (xp >= 10000) return 7;
    if (xp >= 6000) return 6; // Gold
    if (xp >= 4000) return 5;
    if (xp >= 2500) return 4; // Silver
    if (xp >= 1500) return 3;
    if (xp >= 750) return 2; // Bronze
    return 1;
  }

  // ============================================
  // MAPPING FUNCTIONS
  // ============================================

  domain.User _mapToUser(Map<String, dynamic> data) {
    return domain.User(
      id: data['id'] as String,
      schoolId: data['school_id'] as String? ?? '',
      classId: data['class_id'] as String?,
      role: _parseRole(data['role'] as String?),
      studentNumber: data['student_number'] as String?,
      firstName: data['first_name'] as String? ?? '',
      lastName: data['last_name'] as String? ?? '',
      email: data['email'] as String?,
      avatarUrl: data['avatar_url'] as String?,
      xp: data['xp'] as int? ?? 0,
      level: data['level'] as int? ?? 1,
      currentStreak: data['current_streak'] as int? ?? 0,
      longestStreak: data['longest_streak'] as int? ?? 0,
      lastActivityDate: data['last_activity_date'] != null
          ? DateTime.parse(data['last_activity_date'] as String)
          : null,
      settings: (data['settings'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
    );
  }

  UserRole _parseRole(String? role) {
    switch (role) {
      case 'teacher':
        return UserRole.teacher;
      case 'head':
        return UserRole.head;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }
}
