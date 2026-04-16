import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/monthly_quest.dart';
import '../../../domain/repositories/monthly_quest_repository.dart';
import '../../models/monthly_quest/monthly_quest_progress_model.dart';

class SupabaseMonthlyQuestRepository implements MonthlyQuestRepository {
  const SupabaseMonthlyQuestRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<MonthlyQuestProgress>>> getMonthlyQuestProgress(
    String userId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getMonthlyQuestProgress,
        params: {'p_user_id': userId},
      );
      final list = (response as List)
          .map(
            (json) => MonthlyQuestProgressModel.fromJson(
              json as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList();
      return Right(list);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
