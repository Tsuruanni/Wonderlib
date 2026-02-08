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

  /// Open a card pack (atomic: deducts coins, rolls 3 cards, updates collection)
  Future<Either<Failure, PackResult>> openPack(String userId, {int cost = 100});

  /// Get user's current coin balance
  Future<Either<Failure, int>> getUserCoins(String userId);
}
