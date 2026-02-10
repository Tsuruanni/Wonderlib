import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class BuyPackParams {
  const BuyPackParams({required this.userId, this.cost = 100});
  final String userId;
  final int cost;
}

class BuyPackUseCase implements UseCase<BuyPackResult, BuyPackParams> {
  const BuyPackUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, BuyPackResult>> call(BuyPackParams params) {
    return _repository.buyPack(params.userId, cost: params.cost);
  }
}
