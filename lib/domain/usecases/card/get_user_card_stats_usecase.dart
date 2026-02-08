import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetUserCardStatsParams {
  const GetUserCardStatsParams({required this.userId});
  final String userId;
}

class GetUserCardStatsUseCase implements UseCase<UserCardStats, GetUserCardStatsParams> {
  const GetUserCardStatsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, UserCardStats>> call(GetUserCardStatsParams params) {
    return _repository.getUserCardStats(params.userId);
  }
}
