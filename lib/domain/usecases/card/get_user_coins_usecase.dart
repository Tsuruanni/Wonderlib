import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetUserCoinsParams {
  const GetUserCoinsParams({required this.userId});
  final String userId;
}

class GetUserCoinsUseCase implements UseCase<int, GetUserCoinsParams> {
  const GetUserCoinsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, int>> call(GetUserCoinsParams params) {
    return _repository.getUserCoins(params.userId);
  }
}
