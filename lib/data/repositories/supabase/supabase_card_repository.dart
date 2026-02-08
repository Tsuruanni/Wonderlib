import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/card.dart';
import '../../../domain/repositories/card_repository.dart';
import '../../models/card/myth_card_model.dart';
import '../../models/card/pack_result_model.dart';
import '../../models/card/user_card_model.dart';
import '../../models/card/user_card_stats_model.dart';

class SupabaseCardRepository implements CardRepository {
  SupabaseCardRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<MythCard>>> getAllCards() async {
    try {
      final response = await _supabase
          .from('myth_cards')
          .select()
          .eq('is_active', true)
          .order('card_no');

      final cards = (response as List)
          .map((json) => MythCardModel.fromJson(json).toEntity())
          .toList();

      return Right(cards);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MythCard>>> getCardsByCategory(CardCategory category) async {
    try {
      final response = await _supabase
          .from('myth_cards')
          .select()
          .eq('is_active', true)
          .eq('category', category.dbValue)
          .order('card_no');

      final cards = (response as List)
          .map((json) => MythCardModel.fromJson(json).toEntity())
          .toList();

      return Right(cards);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserCard>>> getUserCards(String userId) async {
    try {
      final response = await _supabase
          .from('user_cards')
          .select('*, myth_cards(*)')
          .eq('user_id', userId)
          .order('first_obtained_at', ascending: false);

      final userCards = (response as List)
          .map((json) => UserCardModel.fromJson(json).toEntity())
          .toList();

      return Right(userCards);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserCardStats>> getUserCardStats(String userId) async {
    try {
      final response = await _supabase
          .from('user_card_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // No stats yet — return defaults
        return Right(UserCardStats(userId: userId));
      }

      return Right(UserCardStatsModel.fromJson(response).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PackResult>> openPack(String userId, {int cost = 100}) async {
    try {
      final response = await _supabase.rpc(
        'open_card_pack',
        params: {
          'p_user_id': userId,
          'p_pack_cost': cost,
        },
      );

      final result = PackResultModel.fromJson(response as Map<String, dynamic>);
      return Right(result.toEntity());
    } on PostgrestException catch (e) {
      if (e.message.contains('Insufficient coins')) {
        return const Left(InsufficientFundsFailure('Not enough coins to buy a pack'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getUserCoins(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('coins')
          .eq('id', userId)
          .single();

      return Right(response['coins'] as int? ?? 0);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
