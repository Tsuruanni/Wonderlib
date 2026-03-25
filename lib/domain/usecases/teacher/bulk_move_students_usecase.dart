import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class BulkMoveStudentsParams {

  const BulkMoveStudentsParams({
    required this.studentIds,
    required this.targetClassId,
  });
  final List<String> studentIds;
  final String targetClassId;
}

class BulkMoveStudentsUseCase implements UseCase<void, BulkMoveStudentsParams> {

  const BulkMoveStudentsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(BulkMoveStudentsParams params) {
    return _repository.bulkMoveStudents(
      studentIds: params.studentIds,
      targetClassId: params.targetClassId,
    );
  }
}
