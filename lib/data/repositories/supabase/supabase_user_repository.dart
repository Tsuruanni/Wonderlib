import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/user.dart' as domain;
import '../../../domain/repositories/user_repository.dart';
import '../../models/user/leaderboard_entry_model.dart';
import '../../models/user/user_model.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, domain.User>> getUserById(String id) async {
    try {
      final response =
          await _supabase.from(DbTables.profiles).select().eq('id', id).single();

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
          .from(DbTables.profiles)
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
      await _supabase.rpc(RpcFunctions.awardXpTransaction, params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_source': 'manual',
        'p_source_id': null,
        'p_description': 'XP awarded',
      },);

      // Check for new badges
      await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {
        'p_user_id': userId,
      },);

      // Fetch updated user
      final response = await _supabase
          .from(DbTables.profiles)
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
      await _supabase.rpc(RpcFunctions.updateUserStreak, params: {
        'p_user_id': userId,
      },);

      // Check for new badges (including streak badges)
      await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {
        'p_user_id': userId,
      },);

      // Fetch updated user
      final response = await _supabase
          .from(DbTables.profiles)
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
      final result = await _supabase.rpc(RpcFunctions.getUserStats, params: {
        'p_user_id': userId,
      },);

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
          .from(DbTables.profiles)
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
          .from(DbTables.profiles)
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

  @override
  Future<Either<Failure, List<DateTime>>> getLast7DaysActivity(String userId) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo =
          now.subtract(const Duration(days: 7)).toIso8601String().split('T').first;

      // 1. Get dates from activity_results (quizzes)
      final activitiesResponse = await _supabase
          .from(DbTables.activityResults)
          .select('completed_at')
          .eq('user_id', userId)
          .gte('completed_at', sevenDaysAgo);

      // 2. Get dates from daily_review_sessions (vocabulary)
      final reviewsResponse = await _supabase
          .from(DbTables.dailyReviewSessions)
          .select('session_date')
          .eq('user_id', userId)
          .gte('session_date', sevenDaysAgo);

      // 3. Get dates from daily_chapter_reads (reading completions)
      final readingResponse = await _supabase
          .from(DbTables.dailyChapterReads)
          .select('read_date')
          .eq('user_id', userId)
          .gte('read_date', sevenDaysAgo);

      // 4. Get dates from reading_progress (reading activity)
      final progressResponse = await _supabase
          .from(DbTables.readingProgress)
          .select('updated_at')
          .eq('user_id', userId)
          .gte('updated_at', sevenDaysAgo);

      final dates = <DateTime>{}; // Use Set to avoid duplicates

      // Helper: normalize any date string to local start-of-day
      DateTime toLocalDay(String dateStr) {
        final dt = DateTime.parse(dateStr).toLocal();
        return DateTime(dt.year, dt.month, dt.day);
      }

      // Parse activity dates (timestamp with tz → toLocal)
      for (final row in activitiesResponse as List) {
        dates.add(toLocalDay(row['completed_at'] as String));
      }

      // Parse review dates (DATE type, no tz but normalize consistently)
      for (final row in reviewsResponse as List) {
        dates.add(toLocalDay(row['session_date'] as String));
      }

      // Parse reading completion dates (DATE type)
      for (final row in readingResponse as List) {
        dates.add(toLocalDay(row['read_date'] as String));
      }

      // Parse reading progress dates (timestamp with tz → toLocal)
      for (final row in progressResponse as List) {
        dates.add(toLocalDay(row['updated_at'] as String));
      }

      final sortedDates = dates.toList()..sort((a, b) => b.compareTo(a));

      return Right(sortedDates);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> getTotalClassLeaderboard({
    required String classId,
    int limit = 50,
  }) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.getClassLeaderboard,
        params: {'p_class_id': classId, 'p_limit': limit},
      );

      final data = result as List?;
      if (data == null || data.isEmpty) return const Right([]);

      return Right(data
          .map((json) =>
              LeaderboardEntryModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> getTotalSchoolLeaderboard({
    required String schoolId,
    int limit = 50,
  }) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.getSchoolLeaderboard,
        params: {'p_school_id': schoolId, 'p_limit': limit},
      );

      final data = result as List?;
      if (data == null || data.isEmpty) return const Right([]);

      return Right(data
          .map((json) =>
              LeaderboardEntryModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeaderboardEntry>> getUserClassPosition({
    required String userId,
    required String classId,
  }) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.getUserClassPosition,
        params: {'p_user_id': userId, 'p_class_id': classId},
      );

      if (result == null || (result as List).isEmpty) {
        return const Left(NotFoundFailure('User not found in class leaderboard'));
      }

      return Right(
        LeaderboardEntryModel.fromJson(result[0] as Map<String, dynamic>)
            .toEntity(),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeaderboardEntry>> getUserSchoolPosition({
    required String userId,
    required String schoolId,
  }) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.getUserSchoolPosition,
        params: {'p_user_id': userId, 'p_school_id': schoolId},
      );

      if (result == null || (result as List).isEmpty) {
        return const Left(
            NotFoundFailure('User not found in school leaderboard'));
      }

      return Right(
        LeaderboardEntryModel.fromJson(result[0] as Map<String, dynamic>)
            .toEntity(),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> getWeeklyClassLeaderboard({
    required String classId,
    int limit = 10,
  }) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.getWeeklyClassLeaderboard,
        params: {'p_class_id': classId, 'p_limit': limit},
      );

      final data = result as List?;
      if (data == null || data.isEmpty) {
        return const Right([]);
      }

      final entries = data
          .map((json) =>
              LeaderboardEntryModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList();

      return Right(entries);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> getWeeklySchoolLeaderboard({
    required String schoolId,
    int limit = 10,
    String? leagueTier,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_school_id': schoolId,
        'p_limit': limit,
      };
      if (leagueTier != null) params['p_league_tier'] = leagueTier;

      final result = await _supabase.rpc(
        RpcFunctions.getWeeklySchoolLeaderboard,
        params: params,
      );

      final data = result as List?;
      if (data == null || data.isEmpty) {
        return const Right([]);
      }

      final entries = data
          .map((json) =>
              LeaderboardEntryModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList();

      return Right(entries);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeaderboardEntry>> getUserWeeklyClassPosition({
    required String userId,
    required String classId,
  }) async {
    try {
      final result = await _supabase.rpc(
        RpcFunctions.getUserWeeklyClassPosition,
        params: {'p_user_id': userId, 'p_class_id': classId},
      );

      if (result == null || (result as List).isEmpty) {
        return const Left(NotFoundFailure('User not found in class leaderboard'));
      }

      return Right(
        LeaderboardEntryModel.fromJson(result[0] as Map<String, dynamic>)
            .toEntity(),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeaderboardEntry>> getUserWeeklySchoolPosition({
    required String userId,
    required String schoolId,
    String? leagueTier,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_user_id': userId,
        'p_school_id': schoolId,
      };
      if (leagueTier != null) params['p_league_tier'] = leagueTier;

      final result = await _supabase.rpc(
        RpcFunctions.getUserWeeklySchoolPosition,
        params: params,
      );

      if (result == null || (result as List).isEmpty) {
        return const Left(
            NotFoundFailure('User not found in school leaderboard'));
      }

      return Right(
        LeaderboardEntryModel.fromJson(result[0] as Map<String, dynamic>)
            .toEntity(),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
