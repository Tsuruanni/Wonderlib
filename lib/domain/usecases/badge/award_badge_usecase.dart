import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class AwardBadgeParams {
  final String userId;
  final String badgeId;

  const AwardBadgeParams({
    required this.userId,
    required this.badgeId,
  });
}

class AwardBadgeUseCase implements UseCase<UserBadge, AwardBadgeParams> {
  final BadgeRepository _repository;

  const AwardBadgeUseCase(this._repository);

  @override
  Future<Either<Failure, UserBadge>> call(AwardBadgeParams params) {
    return _repository.awardBadge(
      userId: params.userId,
      badgeId: params.badgeId,
    );
  }
}
