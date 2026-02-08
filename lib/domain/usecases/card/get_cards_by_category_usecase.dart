import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetCardsByCategoryParams {
  const GetCardsByCategoryParams({required this.category});
  final CardCategory category;
}

class GetCardsByCategoryUseCase implements UseCase<List<MythCard>, GetCardsByCategoryParams> {
  const GetCardsByCategoryUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, List<MythCard>>> call(GetCardsByCategoryParams params) {
    return _repository.getCardsByCategory(params.category);
  }
}
