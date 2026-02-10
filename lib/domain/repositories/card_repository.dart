import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/card.dart';

abstract class CardRepository {
  /// Get all 96 cards from the catalog
  Future<Either<Failure, List<MythCard>>> getAllCards();

  /// Get cards filtered by mythology category
  Future<Either<Failure, List<MythCard>>> getCardsByCategory(CardCategory category);

  /// Get all cards owned by a user (with quantities)
  Future<Either<Failure, List<UserCard>>> getUserCards(String userId);

  /// Get user's card collection statistics
  Future<Either<Failure, UserCardStats>> getUserCardStats(String userId);

  /// Buy a card pack (deducts coins, adds to inventory — does NOT open)
  Future<Either<Failure, BuyPackResult>> buyPack(String userId, {int cost = 100});

  /// Open a card pack from inventory (consumes 1 unopened pack, rolls 3 cards)
  Future<Either<Failure, PackResult>> openPack(String userId);

  /// Get user's current coin balance
  Future<Either<Failure, int>> getUserCoins(String userId);

  /// Claim daily quest pack reward (awards 1 pack, once per day)
  Future<Either<Failure, int>> claimDailyQuestPack(String userId);

  /// Check if daily quest pack has been claimed today
  Future<Either<Failure, bool>> hasDailyQuestPackBeenClaimed(String userId);
}
