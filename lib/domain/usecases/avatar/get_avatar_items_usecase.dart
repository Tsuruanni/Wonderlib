import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/avatar.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class GetAvatarItemsUseCase implements UseCase<List<AvatarItem>, NoParams> {
  const GetAvatarItemsUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, List<AvatarItem>>> call(NoParams params) {
    return _repository.getAvatarItems();
  }
}
