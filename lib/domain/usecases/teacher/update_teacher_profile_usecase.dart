import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class UpdateTeacherProfileUseCase implements UseCase<void, UpdateTeacherProfileParams> {
  const UpdateTeacherProfileUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(UpdateTeacherProfileParams params) {
    return _repository.updateProfile(
      firstName: params.firstName,
      lastName: params.lastName,
    );
  }
}

class UpdateTeacherProfileParams {
  const UpdateTeacherProfileParams({
    required this.firstName,
    required this.lastName,
  });
  final String firstName;
  final String lastName;
}
