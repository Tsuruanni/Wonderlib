import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class UpdateClassParams {

  const UpdateClassParams({
    required this.classId,
    required this.name,
    this.description,
  });
  final String classId;
  final String name;
  final String? description;
}

class UpdateClassUseCase implements UseCase<void, UpdateClassParams> {

  const UpdateClassUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(UpdateClassParams params) {
    return _repository.updateClass(
      classId: params.classId,
      name: params.name,
      description: params.description,
    );
  }
}
