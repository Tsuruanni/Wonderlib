import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/avatar.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class GetAvatarBasesUseCase implements UseCase<List<AvatarBase>, NoParams> {
  const GetAvatarBasesUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, List<AvatarBase>>> call(NoParams params) {
    return _repository.getAvatarBases();
  }
}
