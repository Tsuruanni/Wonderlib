import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/card.dart';
import '../../repositories/card_repository.dart';
import '../usecase.dart';

class GetAllCardsUseCase implements UseCase<List<MythCard>, NoParams> {
  const GetAllCardsUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, List<MythCard>>> call(NoParams params) {
    return _repository.getAllCards();
  }
}
