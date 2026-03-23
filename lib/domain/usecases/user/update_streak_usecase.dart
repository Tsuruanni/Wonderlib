import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/streak_result.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class UpdateStreakParams {
  const UpdateStreakParams({required this.userId});
  final String userId;
}

class UpdateStreakUseCase implements UseCase<StreakResult, UpdateStreakParams> {
  const UpdateStreakUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, StreakResult>> call(UpdateStreakParams params) {
    return _repository.updateStreak(params.userId);
  }
}
