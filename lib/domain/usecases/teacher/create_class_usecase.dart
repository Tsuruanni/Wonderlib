import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class CreateClassParams {
  final String schoolId;
  final String name;
  final String? description;

  const CreateClassParams({
    required this.schoolId,
    required this.name,
    this.description,
  });
}

/// Creates a new class
class CreateClassUseCase implements UseCase<String, CreateClassParams> {
  final TeacherRepository _repository;

  const CreateClassUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(CreateClassParams params) {
    return _repository.createClass(
      schoolId: params.schoolId,
      name: params.name,
      description: params.description,
    );
  }
}
