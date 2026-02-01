import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/badge.dart';
import '../../repositories/badge_repository.dart';
import '../usecase.dart';

class GetRecentlyEarnedParams {

  const GetRecentlyEarnedParams({
    required this.userId,
    this.limit = 5,
  });
  final String userId;
  final int limit;
}

class GetRecentlyEarnedUseCase
    implements UseCase<List<Badge>, GetRecentlyEarnedParams> {

  const GetRecentlyEarnedUseCase(this._repository);
  final BadgeRepository _repository;

  @override
  Future<Either<Failure, List<Badge>>> call(GetRecentlyEarnedParams params) {
    return _repository.getRecentlyEarned(
      userId: params.userId,
      limit: params.limit,
    );
  }
}
