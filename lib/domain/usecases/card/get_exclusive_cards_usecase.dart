import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetExclusiveCardsParams {
  const GetExclusiveCardsParams({required this.userId});
  final String userId;
}

class GetExclusiveCardsUseCase
    implements UseCase<List<MythCard>, GetExclusiveCardsParams> {
  const GetExclusiveCardsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, List<MythCard>>> call(GetExclusiveCardsParams params) {
    return _repository.getExclusiveCards(params.userId);
  }
}
