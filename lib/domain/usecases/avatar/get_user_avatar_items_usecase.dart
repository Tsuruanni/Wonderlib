import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/avatar.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class GetUserAvatarItemsUseCase implements UseCase<List<UserAvatarItem>, GetUserAvatarItemsParams> {
  const GetUserAvatarItemsUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, List<UserAvatarItem>>> call(GetUserAvatarItemsParams params) {
    return _repository.getUserAvatarItems(params.userId);
  }
}

class GetUserAvatarItemsParams {
  const GetUserAvatarItemsParams({required this.userId});
  final String userId;
}
