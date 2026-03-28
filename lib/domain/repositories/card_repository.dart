import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/card.dart';

abstract class CardRepository {
  /// Get all 96 cards from the catalog
  Future<Either<Failure, List<MythCard>>> getAllCards();

  /// Get all cards owned by a user (with quantities)
  Future<Either<Failure, List<UserCard>>> getUserCards(String userId);

  /// Get user's card collection statistics
  Future<Either<Failure, UserCardStats>> getUserCardStats(String userId);

  /// Buy a card pack (deducts coins, adds to inventory — does NOT open)
  Future<Either<Failure, BuyPackResult>> buyPack(String userId, {int cost = 100});

  /// Open a card pack from inventory (consumes 1 unopened pack, rolls 3 cards)
  Future<Either<Failure, PackResult>> openPack(String userId);
}
