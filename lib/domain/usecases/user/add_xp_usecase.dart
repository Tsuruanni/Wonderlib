import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class AddXPParams {
  const AddXPParams({
    required this.userId,
    required this.amount,
    this.source = 'manual',
    this.sourceId,
  });
  final String userId;
  final int amount;
  final String source;
  final String? sourceId;
}

class AddXPUseCase implements UseCase<User, AddXPParams> {
  const AddXPUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, User>> call(AddXPParams params) {
    return _repository.addXP(
      params.userId,
      params.amount,
      source: params.source,
      sourceId: params.sourceId,
    );
  }
}
