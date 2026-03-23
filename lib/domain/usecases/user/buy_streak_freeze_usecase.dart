import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/streak_result.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class BuyStreakFreezeParams {
  const BuyStreakFreezeParams({required this.userId});
  final String userId;
}

class BuyStreakFreezeUseCase implements UseCase<BuyFreezeResult, BuyStreakFreezeParams> {
  const BuyStreakFreezeUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, BuyFreezeResult>> call(BuyStreakFreezeParams params) {
    return _repository.buyStreakFreeze(params.userId);
  }
}
