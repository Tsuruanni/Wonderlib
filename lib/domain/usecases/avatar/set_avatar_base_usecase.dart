import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class SetAvatarBaseUseCase implements UseCase<void, SetAvatarBaseParams> {
  const SetAvatarBaseUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, void>> call(SetAvatarBaseParams params) {
    return _repository.setAvatarBase(params.baseId);
  }
}

class SetAvatarBaseParams {
  const SetAvatarBaseParams({required this.baseId});
  final String baseId;
}
