import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/avatar.dart';
import '../../../domain/repositories/avatar_repository.dart';
import '../../models/avatar/avatar_base_model.dart';
import '../../models/avatar/avatar_item_model.dart';
import '../../models/avatar/user_avatar_item_model.dart';

class SupabaseAvatarRepository implements AvatarRepository {
  SupabaseAvatarRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<AvatarBase>>> getAvatarBases() async {
    try {
      final response = await _supabase
          .from(DbTables.avatarBases)
          .select()
          .order('sort_order');

      final bases = (response as List)
          .map((json) => AvatarBaseModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();

      return Right(bases);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setAvatarBase(String baseId) async {
    try {
      await _supabase.rpc(RpcFunctions.setAvatarBase, params: {'p_base_id': baseId});
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AvatarItem>>> getAvatarItems() async {
    try {
      final response = await _supabase
          .from(DbTables.avatarItems)
          .select('*, avatar_item_categories(*)')
          .eq('is_active', true)
          .order('coin_price');

      final items = (response as List)
          .map((json) => AvatarItemModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();

      return Right(items);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserAvatarItem>>> getUserAvatarItems(String userId) async {
    try {
      final response = await _supabase
          .from(DbTables.userAvatarItems)
          .select('*, avatar_items(*, avatar_item_categories(*))')
          .eq('user_id', userId);

      final userItems = (response as List)
          .map((json) => UserAvatarItemModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();

      return Right(userItems);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BuyAvatarItemResult>> buyAvatarItem(String itemId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.buyAvatarItem,
        params: {'p_item_id': itemId},
      );

      final json = response as Map<String, dynamic>;
      return Right(
        BuyAvatarItemResult(
          coinsRemaining: json['coins_remaining'] as int,
          itemId: json['item_id'] as String,
        ),
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('Insufficient coins')) {
        return const Left(InsufficientFundsFailure('Not enough coins'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> equipAvatarItem(String itemId) async {
    try {
      await _supabase.rpc(RpcFunctions.equipAvatarItem, params: {'p_item_id': itemId});
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unequipAvatarItem(String itemId) async {
    try {
      await _supabase.rpc(RpcFunctions.unequipAvatarItem, params: {'p_item_id': itemId});
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

}
