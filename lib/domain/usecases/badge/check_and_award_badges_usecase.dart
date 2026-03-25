import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge_earned.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class CheckAndAwardBadgesUseCase
    implements UseCase<List<BadgeEarned>, CheckAndAwardBadgesParams> {
  const CheckAndAwardBadgesUseCase(this._repository);

  final BadgeRepository _repository;

  @override
  Future<Either<Failure, List<BadgeEarned>>> call(
    CheckAndAwardBadgesParams params,
  ) {
    return _repository.checkAndAwardBadges(params.userId);
  }
}

class CheckAndAwardBadgesParams {
  const CheckAndAwardBadgesParams({required this.userId});

  final String userId;
}
