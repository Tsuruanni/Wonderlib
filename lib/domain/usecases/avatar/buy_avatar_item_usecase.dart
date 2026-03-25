import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/avatar.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class BuyAvatarItemUseCase implements UseCase<BuyAvatarItemResult, BuyAvatarItemParams> {
  const BuyAvatarItemUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, BuyAvatarItemResult>> call(BuyAvatarItemParams params) {
    return _repository.buyAvatarItem(params.itemId);
  }
}

class BuyAvatarItemParams {
  const BuyAvatarItemParams({required this.itemId});
  final String itemId;
}
