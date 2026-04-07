import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/treasure_wheel.dart';
import '../../repositories/treasure_repository.dart';
import '../usecase.dart';

class GetWheelSlicesUseCase implements UseCase<List<TreasureWheelSlice>, NoParams> {
  const GetWheelSlicesUseCase(this._repository);
  final TreasureRepository _repository;

  @override
  Future<Either<Failure, List<TreasureWheelSlice>>> call(NoParams params) {
    return _repository.getWheelSlices();
  }
}
