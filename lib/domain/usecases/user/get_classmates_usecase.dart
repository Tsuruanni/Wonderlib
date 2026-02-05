import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetClassmatesParams {

  const GetClassmatesParams({required this.classId});
  final String classId;
}

class GetClassmatesUseCase implements UseCase<List<User>, GetClassmatesParams> {

  const GetClassmatesUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, List<User>>> call(GetClassmatesParams params) {
    return _repository.getClassmates(params.classId);
  }
}
