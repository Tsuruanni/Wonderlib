import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetClassmatesParams {
  final String classId;

  const GetClassmatesParams({required this.classId});
}

class GetClassmatesUseCase implements UseCase<List<User>, GetClassmatesParams> {
  final UserRepository _repository;

  const GetClassmatesUseCase(this._repository);

  @override
  Future<Either<Failure, List<User>>> call(GetClassmatesParams params) {
    return _repository.getClassmates(params.classId);
  }
}
