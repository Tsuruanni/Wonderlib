import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class GetBadgeByIdParams {

  const GetBadgeByIdParams({required this.badgeId});
  final String badgeId;
}

class GetBadgeByIdUseCase implements UseCase<Badge, GetBadgeByIdParams> {

  const GetBadgeByIdUseCase(this._repository);
  final BadgeRepository _repository;

  @override
  Future<Either<Failure, Badge>> call(GetBadgeByIdParams params) {
    return _repository.getBadgeById(params.badgeId);
  }
}
