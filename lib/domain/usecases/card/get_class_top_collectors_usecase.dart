import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetClassTopCollectorsParams {
  const GetClassTopCollectorsParams({required this.userId});
  final String userId;
}

class GetClassTopCollectorsUseCase
    implements UseCase<TopCollectorsResult, GetClassTopCollectorsParams> {
  const GetClassTopCollectorsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, TopCollectorsResult>> call(
      GetClassTopCollectorsParams params,) {
    return _repository.getClassTopCollectors(params.userId);
  }
}
