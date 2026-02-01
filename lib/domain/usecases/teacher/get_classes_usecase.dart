import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetClassesParams {
  final String schoolId;

  const GetClassesParams({required this.schoolId});
}

/// Gets list of classes for a teacher's school
class GetClassesUseCase
    implements UseCase<List<TeacherClass>, GetClassesParams> {
  final TeacherRepository _repository;

  const GetClassesUseCase(this._repository);

  @override
  Future<Either<Failure, List<TeacherClass>>> call(GetClassesParams params) {
    return _repository.getClasses(params.schoolId);
  }
}
