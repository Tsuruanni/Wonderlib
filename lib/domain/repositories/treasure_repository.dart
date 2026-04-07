import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/treasure_wheel.dart';

abstract class TreasureRepository {
  /// Get all active wheel slices for rendering
  Future<Either<Failure, List<TreasureWheelSlice>>> getWheelSlices();

  /// Spin the wheel: weighted random selection + award + mark complete
  Future<Either<Failure, TreasureSpinResult>> spinWheel({
    required String userId,
    required String unitId,
  });
}
