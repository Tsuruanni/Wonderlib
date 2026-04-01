import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class TradeDuplicateCardsParams {
  const TradeDuplicateCardsParams({
    required this.userId,
    required this.cardQuantities,
    required this.targetRarity,
    this.idempotencyKey,
  });
  final String userId;
  final Map<String, int> cardQuantities;
  final String targetRarity;
  final String? idempotencyKey;
}

class TradeDuplicateCardsUseCase
    implements UseCase<TradeResult, TradeDuplicateCardsParams> {
  const TradeDuplicateCardsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, TradeResult>> call(TradeDuplicateCardsParams params) {
    return _repository.tradeDuplicateCards(
      params.userId,
      cardQuantities: params.cardQuantities,
      targetRarity: params.targetRarity,
      idempotencyKey: params.idempotencyKey,
    );
  }
}
