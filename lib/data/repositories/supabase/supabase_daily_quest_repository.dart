import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/daily_quest.dart';
import '../../../domain/repositories/daily_quest_repository.dart';
import '../../models/daily_quest/daily_quest_progress_model.dart';

class SupabaseDailyQuestRepository implements DailyQuestRepository {
  const SupabaseDailyQuestRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<DailyQuestProgress>>> getDailyQuestProgress(String userId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getDailyQuestProgress,
        params: {'p_user_id': userId},
      );
      final list = (response as List)
          .map((json) => DailyQuestProgressModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DailyBonusResult>> claimDailyBonus(String userId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.claimDailyBonus,
        params: {'p_user_id': userId},
      );
      final data = response as Map<String, dynamic>;
      return Right(
        DailyBonusResult(
          success: data['success'] as bool? ?? false,
          unopenedPacks: data['unopened_packs'] as int? ?? 0,
        ),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasDailyBonusClaimed(String userId) async {
    try {
      final today = AppClock.now().toUtc().toIso8601String().substring(0, 10);
      final response = await _supabase
          .from(DbTables.dailyQuestBonusClaims)
          .select('id')
          .eq('user_id', userId)
          .eq('claim_date', today)
          .maybeSingle();
      return Right(response != null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
