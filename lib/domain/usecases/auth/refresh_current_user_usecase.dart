import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/auth_repository.dart';
import '../usecase.dart';

class RefreshCurrentUserUseCase implements UseCase<void, NoParams> {

  const RefreshCurrentUserUseCase(this._repository);
  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    try {
      await _repository.refreshCurrentUser();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
