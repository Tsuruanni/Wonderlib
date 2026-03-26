import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class CreateClassParams {

  const CreateClassParams({
    required this.schoolId,
    required this.name,
    required this.grade,
    this.description,
  });
  final String schoolId;
  final String name;
  final int grade;
  final String? description;
}

/// Creates a new class
class CreateClassUseCase implements UseCase<String, CreateClassParams> {

  const CreateClassUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, String>> call(CreateClassParams params) {
    return _repository.createClass(
      schoolId: params.schoolId,
      name: params.name,
      grade: params.grade,
      description: params.description,
    );
  }
}
