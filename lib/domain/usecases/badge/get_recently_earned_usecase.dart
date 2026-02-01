import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class GetRecentlyEarnedParams {
  final String userId;
  final int limit;

  const GetRecentlyEarnedParams({
    required this.userId,
    this.limit = 5,
  });
}

class GetRecentlyEarnedUseCase
    implements UseCase<List<Badge>, GetRecentlyEarnedParams> {
  final BadgeRepository _repository;

  const GetRecentlyEarnedUseCase(this._repository);

  @override
  Future<Either<Failure, List<Badge>>> call(GetRecentlyEarnedParams params) {
    return _repository.getRecentlyEarned(
      userId: params.userId,
      limit: params.limit,
    );
  }
}
