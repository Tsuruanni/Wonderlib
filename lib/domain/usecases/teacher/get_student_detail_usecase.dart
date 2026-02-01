import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetStudentDetailParams {

  const GetStudentDetailParams({required this.studentId});
  final String studentId;
}

/// Gets detailed student info for student detail screen
class GetStudentDetailUseCase
    implements UseCase<User, GetStudentDetailParams> {

  const GetStudentDetailUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, User>> call(GetStudentDetailParams params) {
    return _repository.getStudentDetail(params.studentId);
  }
}
