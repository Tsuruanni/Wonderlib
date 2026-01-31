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
      // Get current XP
      final currentUser = await _supabase
          .from('profiles')
          .select('xp, level')
          .eq('id', userId)
          .single();

      final currentXP = currentUser['xp'] as int? ?? 0;
      final newXP = currentXP + amount;

      // Calculate new level
      final newLevel = _calculateLevel(newXP);

      // Update profile
      final response = await _supabase
          .from('profiles')
          .update({
            'xp': newXP,
            'level': newLevel,
            'last_activity_date': DateTime.now().toIso8601String().split('T')[0],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      // Log XP
      await _supabase.from('xp_logs').insert({
        'user_id': userId,
        'amount': amount,
        'reason': 'xp_award',
        'created_at': DateTime.now().toIso8601String(),
      });

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
      final response = await _supabase
          .from('profiles')
          .select('current_streak, longest_streak, last_activity_date')
          .eq('id', userId)
          .single();

      final lastActivityStr = response['last_activity_date'] as String?;
      final currentStreak = response['current_streak'] as int? ?? 0;
      final longestStreak = response['longest_streak'] as int? ?? 0;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      int newStreak = currentStreak;
      int newLongest = longestStreak;

      if (lastActivityStr != null) {
        final lastActivity = DateTime.parse(lastActivityStr);
        final lastActivityDate = DateTime(
          lastActivity.year,
          lastActivity.month,
          lastActivity.day,
        );

        final daysDiff = todayDate.difference(lastActivityDate).inDays;

        if (daysDiff == 0) {
          // Same day, no change
        } else if (daysDiff == 1) {
          // Consecutive day
          newStreak = currentStreak + 1;
          if (newStreak > longestStreak) {
            newLongest = newStreak;
          }
        } else {
          // Streak broken
          newStreak = 1;
        }
      } else {
        // First activity
        newStreak = 1;
        if (newStreak > longestStreak) {
          newLongest = newStreak;
        }
      }

      final updateResponse = await _supabase
          .from('profiles')
          .update({
            'current_streak': newStreak,
            'longest_streak': newLongest,
            'last_activity_date': todayDate.toIso8601String().split('T')[0],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();

      return Right(_mapToUser(updateResponse));
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
      // Get user profile
      final profile = await _supabase
          .from('profiles')
          .select('xp, level, current_streak, longest_streak')
          .eq('id', userId)
          .single();

      // Get reading stats
      final readingProgress = await _supabase
          .from('reading_progress')
          .select('id, is_completed, total_reading_time')
          .eq('user_id', userId);

      final progressList = readingProgress as List;
      final booksStarted = progressList.length;
      final booksCompleted =
          progressList.where((p) => p['is_completed'] == true).length;
      final totalReadingTime = progressList.fold<int>(
        0,
        (sum, p) => sum + (p['total_reading_time'] as int? ?? 0),
      );

      // Get activity stats
      final activityResults = await _supabase
          .from('activity_results')
          .select('id')
          .eq('user_id', userId);

      // Get vocabulary stats
      final vocabProgress = await _supabase
          .from('vocabulary_progress')
          .select('id, status')
          .eq('user_id', userId);

      final vocabList = vocabProgress as List;
      final wordsLearned = vocabList.length;
      final wordsMastered =
          vocabList.where((v) => v['status'] == 'mastered').length;

      return Right({
        'xp': profile['xp'] as int? ?? 0,
        'level': profile['level'] as int? ?? 1,
        'current_streak': profile['current_streak'] as int? ?? 0,
        'longest_streak': profile['longest_streak'] as int? ?? 0,
        'books_started': booksStarted,
        'books_completed': booksCompleted,
        'total_reading_time': totalReadingTime,
        'activities_completed': (activityResults as List).length,
        'words_learned': wordsLearned,
        'words_mastered': wordsMastered,
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
