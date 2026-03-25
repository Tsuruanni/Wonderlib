import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/class_learning_path_unit.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetClassLearningPathUnitsParams {
  const GetClassLearningPathUnitsParams({required this.classId});
  final String classId;
}

class GetClassLearningPathUnitsUseCase
    implements UseCase<List<ClassLearningPathUnit>, GetClassLearningPathUnitsParams> {
  const GetClassLearningPathUnitsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<ClassLearningPathUnit>>> call(
    GetClassLearningPathUnitsParams params,
  ) {
    return _repository.getClassLearningPathUnits(params.classId);
  }
}
