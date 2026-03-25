import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class UnequipAvatarItemUseCase implements UseCase<void, UnequipAvatarItemParams> {
  const UnequipAvatarItemUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, void>> call(UnequipAvatarItemParams params) {
    return _repository.unequipAvatarItem(params.itemId);
  }
}

class UnequipAvatarItemParams {
  const UnequipAvatarItemParams({required this.itemId});
  final String itemId;
}
