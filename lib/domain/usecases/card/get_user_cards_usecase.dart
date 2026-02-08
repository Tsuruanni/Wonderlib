import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetUserCardsParams {
  const GetUserCardsParams({required this.userId});
  final String userId;
}

class GetUserCardsUseCase implements UseCase<List<UserCard>, GetUserCardsParams> {
  const GetUserCardsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, List<UserCard>>> call(GetUserCardsParams params) {
    return _repository.getUserCards(params.userId);
  }
}
