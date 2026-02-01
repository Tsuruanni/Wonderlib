import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class UpdateStreakParams {
  final String userId;

  const UpdateStreakParams({required this.userId});
}

class UpdateStreakUseCase implements UseCase<User, UpdateStreakParams> {
  final UserRepository _repository;

  const UpdateStreakUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(UpdateStreakParams params) {
    return _repository.updateStreak(params.userId);
  }
}
