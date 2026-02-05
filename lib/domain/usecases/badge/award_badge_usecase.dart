import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class AwardBadgeParams {

  const AwardBadgeParams({
    required this.userId,
    required this.badgeId,
  });
  final String userId;
  final String badgeId;
}

class AwardBadgeUseCase implements UseCase<UserBadge, AwardBadgeParams> {

  const AwardBadgeUseCase(this._repository);
  final BadgeRepository _repository;

  @override
  Future<Either<Failure, UserBadge>> call(AwardBadgeParams params) {
    return _repository.awardBadge(
      userId: params.userId,
      badgeId: params.badgeId,
    );
  }
}
