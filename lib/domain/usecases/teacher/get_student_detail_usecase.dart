import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/user.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetStudentDetailParams {
  final String studentId;

  const GetStudentDetailParams({required this.studentId});
}

/// Gets detailed student info for student detail screen
class GetStudentDetailUseCase
    implements UseCase<User, GetStudentDetailParams> {
  final TeacherRepository _repository;

  const GetStudentDetailUseCase(this._repository);

  @override
  Future<Either<Failure, User>> call(GetStudentDetailParams params) {
    return _repository.getStudentDetail(params.studentId);
  }
}
