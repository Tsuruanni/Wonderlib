import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/avatar.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class GetEquippedAvatarUseCase implements UseCase<EquippedAvatar, GetEquippedAvatarParams> {
  const GetEquippedAvatarUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, EquippedAvatar>> call(GetEquippedAvatarParams params) {
    return _repository.getEquippedAvatar(params.userId);
  }
}

class GetEquippedAvatarParams {
  const GetEquippedAvatarParams({required this.userId});
  final String userId;
}
