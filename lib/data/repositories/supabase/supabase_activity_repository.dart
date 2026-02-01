import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../models/activity/activity_model.dart';
import '../../models/activity/activity_result_model.dart';

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<Activity>>> getActivitiesByChapter(
    String chapterId,
  ) async {
    try {
      final response = await _supabase
          .from('activities')
          .select()
          .eq('chapter_id', chapterId)
          .order('order_index', ascending: true);

      final activities = (response as List)
          .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();

      return Right(activities);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Activity>> getActivityById(String id) async {
    try {
      final response =
          await _supabase.from('activities').select().eq('id', id).single();

      return Right(ActivityModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return const Left(NotFoundFailure('Activity not found'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ActivityResult>> submitActivityResult(
    ActivityResult result,
  ) async {
    try {
      // Get attempt number (count existing results + 1)
      final existingResults = await _supabase
          .from('activity_results')
          .select('id')
          .eq('user_id', result.userId)
          .eq('activity_id', result.activityId);

      final attemptNumber = (existingResults as List).length + 1;

      final resultModel = ActivityResultModel.fromEntity(result);
      final data = {
        'user_id': resultModel.userId,
        'activity_id': resultModel.activityId,
        'score': resultModel.score,
        'max_score': resultModel.maxScore,
        'answers': resultModel.answers,
        'time_spent': resultModel.timeSpent,
        'attempt_number': attemptNumber,
        'completed_at': resultModel.completedAt.toIso8601String(),
      };

      final response = await _supabase
          .from('activity_results')
          .insert(data)
          .select()
          .single();

      // Award XP based on score (if first attempt or better score)
      if (attemptNumber == 1 || result.score == result.maxScore) {
        final xpToAward = _calculateXP(result.score, result.maxScore);
        if (xpToAward > 0) {
          await _awardXP(
            result.userId,
            xpToAward,
            'activity',
            sourceId: result.activityId,
            description: 'Activity completed',
          );
        }
      }

      return Right(ActivityResultModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ActivityResult>>> getUserActivityResults({
    required String userId,
    String? activityId,
  }) async {
    try {
      var query = _supabase
          .from('activity_results')
          .select()
          .eq('user_id', userId);

      if (activityId != null) {
        query = query.eq('activity_id', activityId);
      }

      final response = await query.order('completed_at', ascending: false);

      final results = (response as List)
          .map((json) => ActivityResultModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();

      return Right(results);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ActivityResult?>> getBestResult({
    required String userId,
    required String activityId,
  }) async {
    try {
      final response = await _supabase
          .from('activity_results')
          .select()
          .eq('user_id', userId)
          .eq('activity_id', activityId)
          .order('score', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return const Right(null);
      }

      return Right(ActivityResultModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getActivityStats(
    String userId,
  ) async {
    try {
      // Get total activities completed
      final resultsResponse = await _supabase
          .from('activity_results')
          .select('id, score, max_score')
          .eq('user_id', userId);

      final results = resultsResponse as List;
      final totalCompleted = results.length;

      // Calculate average score
      double totalScore = 0;
      double totalMaxScore = 0;
      int perfectScores = 0;

      for (final result in results) {
        final score = (result['score'] as num).toDouble();
        final maxScore = (result['max_score'] as num).toDouble();
        totalScore += score;
        totalMaxScore += maxScore;
        if (score == maxScore) perfectScores++;
      }

      final averagePercentage =
          totalMaxScore > 0 ? (totalScore / totalMaxScore) * 100 : 0.0;

      return Right({
        'total_completed': totalCompleted,
        'average_score': averagePercentage.round(),
        'perfect_scores': perfectScores,
      });
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  int _calculateXP(double score, double maxScore) {
    if (maxScore == 0) return 0;
    final percentage = (score / maxScore) * 100;
    if (percentage >= 100) return 10; // Perfect
    if (percentage >= 80) return 7;
    if (percentage >= 60) return 5;
    return 2; // Participation XP
  }

  Future<Map<String, dynamic>?> _awardXP(
    String userId,
    int amount,
    String source, {
    String? sourceId,
    String? description,
  }) async {
    try {
      // Use the stored function for atomic XP award + level calculation
      final result = await _supabase.rpc('award_xp_transaction', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_source': source,
        'p_source_id': sourceId,
        'p_description': description,
      });

      // Also check for new badges
      await _supabase.rpc('check_and_award_badges', params: {
        'p_user_id': userId,
      });

      if (result != null && (result as List).isNotEmpty) {
        return result[0] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      // Log but don't fail the main operation
      // ignore: avoid_print
      print('Failed to award XP: $e');
      return null;
    }
  }

}
