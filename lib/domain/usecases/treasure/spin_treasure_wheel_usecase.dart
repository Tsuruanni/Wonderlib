import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/treasure_wheel.dart';
import '../../repositories/treasure_repository.dart';
import '../usecase.dart';

class SpinTreasureWheelParams {
  const SpinTreasureWheelParams({required this.userId, required this.unitId});
  final String userId;
  final String unitId;
}

class SpinTreasureWheelUseCase implements UseCase<TreasureSpinResult, SpinTreasureWheelParams> {
  const SpinTreasureWheelUseCase(this._repository);
  final TreasureRepository _repository;

  @override
  Future<Either<Failure, TreasureSpinResult>> call(SpinTreasureWheelParams params) {
    return _repository.spinWheel(userId: params.userId, unitId: params.unitId);
  }
}
