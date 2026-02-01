import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class CheckEarnableBadgesParams {
  final String userId;

  const CheckEarnableBadgesParams({required this.userId});
}

class CheckEarnableBadgesUseCase
    implements UseCase<List<Badge>, CheckEarnableBadgesParams> {
  final BadgeRepository _repository;

  const CheckEarnableBadgesUseCase(this._repository);

  @override
  Future<Either<Failure, List<Badge>>> call(CheckEarnableBadgesParams params) {
    return _repository.checkEarnableBadges(params.userId);
  }
}
