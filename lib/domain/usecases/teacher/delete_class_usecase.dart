import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class DeleteClassParams {

  const DeleteClassParams({required this.classId});
  final String classId;
}

class DeleteClassUseCase implements UseCase<void, DeleteClassParams> {

  const DeleteClassUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(DeleteClassParams params) {
    return _repository.deleteClass(params.classId);
  }
}
