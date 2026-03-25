import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class EquipAvatarItemUseCase implements UseCase<void, EquipAvatarItemParams> {
  const EquipAvatarItemUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, void>> call(EquipAvatarItemParams params) {
    return _repository.equipAvatarItem(params.itemId);
  }
}

class EquipAvatarItemParams {
  const EquipAvatarItemParams({required this.itemId});
  final String itemId;
}
