import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class GetBadgeByIdParams {
  final String badgeId;

  const GetBadgeByIdParams({required this.badgeId});
}

class GetBadgeByIdUseCase implements UseCase<Badge, GetBadgeByIdParams> {
  final BadgeRepository _repository;

  const GetBadgeByIdUseCase(this._repository);

  @override
  Future<Either<Failure, Badge>> call(GetBadgeByIdParams params) {
    return _repository.getBadgeById(params.badgeId);
  }
}
