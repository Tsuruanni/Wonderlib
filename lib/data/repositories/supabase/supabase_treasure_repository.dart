import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/treasure_wheel.dart';
import '../../../domain/repositories/treasure_repository.dart';
import '../../models/treasure/treasure_spin_result_model.dart';
import '../../models/treasure/treasure_wheel_slice_model.dart';

class SupabaseTreasureRepository implements TreasureRepository {
  SupabaseTreasureRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<TreasureWheelSlice>>> getWheelSlices() async {
    try {
      final response = await _supabase
          .from(DbTables.treasureWheelSlices)
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final slices = (response as List)
          .map((json) => TreasureWheelSliceModel.fromJson(json).toEntity())
          .toList();

      return Right(slices);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TreasureSpinResult>> spinWheel({
    required String userId,
    required String unitId,
  }) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.spinTreasureWheel,
        params: {
          'p_user_id': userId,
          'p_unit_id': unitId,
        },
      );

      final result = TreasureSpinResultModel.fromJson(response as Map<String, dynamic>);
      return Right(result.toEntity());
    } on PostgrestException catch (e) {
      if (e.message.contains('ALREADY_CLAIMED')) {
        return const Left(ServerFailure('Treasure already claimed', code: 'ALREADY_CLAIMED'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
