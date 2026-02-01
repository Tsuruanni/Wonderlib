import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class CheckEarnableBadgesParams {

  const CheckEarnableBadgesParams({required this.userId});
  final String userId;
}

class CheckEarnableBadgesUseCase
    implements UseCase<List<Badge>, CheckEarnableBadgesParams> {

  const CheckEarnableBadgesUseCase(this._repository);
  final BadgeRepository _repository;

  @override
  Future<Either<Failure, List<Badge>>> call(CheckEarnableBadgesParams params) {
    return _repository.checkEarnableBadges(params.userId);
  }
}
