import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class OpenPackParams {
  const OpenPackParams({required this.userId, this.cost = 100});
  final String userId;
  final int cost;
}

class OpenPackUseCase implements UseCase<PackResult, OpenPackParams> {
  const OpenPackUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, PackResult>> call(OpenPackParams params) {
    return _repository.openPack(params.userId, cost: params.cost);
  }
}
