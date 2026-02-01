import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class GetUserBadgesParams {
  final String userId;

  const GetUserBadgesParams({required this.userId});
}

class GetUserBadgesUseCase
    implements UseCase<List<UserBadge>, GetUserBadgesParams> {
  final BadgeRepository _repository;

  const GetUserBadgesUseCase(this._repository);

  @override
  Future<Either<Failure, List<UserBadge>>> call(GetUserBadgesParams params) {
    return _repository.getUserBadges(params.userId);
  }
}
