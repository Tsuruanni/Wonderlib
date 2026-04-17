import 'package:dartz/dartz.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/card.dart';
import '../../../domain/repositories/card_repository.dart';
import '../../models/card/buy_pack_result_model.dart';
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
          .from(DbTables.mythCards)
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
  Future<Either<Failure, List<UserCard>>> getUserCards(String userId) async {
    try {
      final response = await _supabase
          .from(DbTables.userCards)
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
          .from(DbTables.userCardStats)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
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
  Future<Either<Failure, BuyPackResult>> buyPack(String userId, {int cost = 100, String? idempotencyKey}) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.buyCardPack,
        params: {
          'p_user_id': userId,
          'p_pack_cost': cost,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );

      final result = BuyPackResultModel.fromJson(response as Map<String, dynamic>);
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
  Future<Either<Failure, PackResult>> openPack(String userId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.openCardPack,
        params: {
          'p_user_id': userId,
        },
      );

      final result = PackResultModel.fromJson(response as Map<String, dynamic>);
      return Right(result.toEntity());
    } on PostgrestException catch (e) {
      if (e.message.contains('No unopened packs')) {
        return const Left(ServerFailure('No packs available to open'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TopCollectorsResult>> getClassTopCollectors(
      String userId,) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getClassTopCollectors,
        params: {'p_user_id': userId},
      );

      final json = response as Map<String, dynamic>;

      TopCollectorEntry parseEntry(Map<String, dynamic> e) {
        return TopCollectorEntry(
          userId: e['user_id'] as String,
          firstName: e['first_name'] as String,
          lastName: (e['last_name'] as String?) ?? '',
          avatarUrl: e['avatar_url'] as String?,
          avatarEquippedCache:
              (e['avatar_equipped_cache'] as Map?)?.cast<String, dynamic>(),
          totalXp: (e['total_xp'] as num?)?.toInt() ?? 0,
          level: (e['level'] as num?)?.toInt() ?? 1,
          leagueTier: (e['league_tier'] as String?) ?? 'bronze',
          uniqueCards: (e['unique_cards'] as num).toInt(),
          rank: (e['rank'] as num).toInt(),
        );
      }

      final top3 = (json['top3'] as List)
          .map((e) => parseEntry(e as Map<String, dynamic>))
          .toList();
      final callerJson = json['caller'] as Map<String, dynamic>?;

      return Right(TopCollectorsResult(
        top3: top3,
        caller: callerJson != null ? parseEntry(callerJson) : null,
      ),);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MythCard>>> getExclusiveCards(
      String userId,) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getExclusiveCards,
        params: {'p_user_id': userId},
      );

      final cards = (response as List)
          .map((json) => MythCard(
                id: json['id'] as String,
                cardNo: json['card_no'] as String,
                name: json['name'] as String,
                category: CardCategory.fromDbValue(json['category'] as String),
                rarity: CardRarity.fromDbValue(json['rarity'] as String),
                power: (json['power'] as num).toInt(),
                imageUrl: json['image_url'] as String?,
                createdAt: DateTime.utc(2000), // not returned by RPC, display-only
              ),)
          .toList();
      return Right(cards);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CardOwnersInClass>> getCardOwnersInClass(
      String userId, String cardId,) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getCardOwnersInClass,
        params: {'p_user_id': userId, 'p_card_id': cardId},
      );

      final json = response as Map<String, dynamic>;
      final owners = (json['owners'] as List).cast<String>();
      final totalStudents = (json['total_students'] as num).toInt();

      return Right(CardOwnersInClass(
        ownerNames: owners,
        totalStudents: totalStudents,
      ),);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TradeResult>> tradeDuplicateCards(
    String userId, {
    required Map<String, int> cardQuantities,
    required String targetRarity,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.tradeDuplicateCards,
        params: {
          'p_user_id': userId,
          'p_card_quantities': cardQuantities,
          'p_target_rarity': targetRarity,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );

      final json = response as Map<String, dynamic>;
      final cardJson = json['received_card'] as Map<String, dynamic>;

      final receivedCard = MythCard(
        id: cardJson['id'] as String,
        cardNo: cardJson['card_no'] as String,
        name: cardJson['name'] as String,
        category: CardCategory.fromDbValue(cardJson['category'] as String),
        rarity: CardRarity.fromDbValue(cardJson['rarity'] as String),
        power: (cardJson['power'] as num).toInt(),
        specialSkill: cardJson['special_skill'] as String?,
        description: cardJson['description'] as String?,
        categoryIcon: cardJson['category_icon'] as String?,
        imageUrl: cardJson['image_url'] as String?,
        createdAt: DateTime.utc(2000),
      );

      return Right(TradeResult(
        receivedCard: receivedCard,
        isNew: json['is_new'] as bool,
        quantity: (json['quantity'] as num).toInt(),
      ),);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
