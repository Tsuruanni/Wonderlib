import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetClassesParams {

  const GetClassesParams({required this.schoolId});
  final String schoolId;
}

/// Gets list of classes for a teacher's school
class GetClassesUseCase
    implements UseCase<List<TeacherClass>, GetClassesParams> {

  const GetClassesUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<TeacherClass>>> call(GetClassesParams params) {
    return _repository.getClasses(params.schoolId);
  }
}
