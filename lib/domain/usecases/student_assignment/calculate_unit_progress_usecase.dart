import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class CalculateUnitProgressParams {
  const CalculateUnitProgressParams({
    required this.assignmentId,
    required this.studentId,
  });
  final String assignmentId;
  final String studentId;
}

class CalculateUnitProgressUseCase
    implements UseCase<void, CalculateUnitProgressParams> {
  const CalculateUnitProgressUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, void>> call(CalculateUnitProgressParams params) {
    return _repository.calculateUnitProgress(params.assignmentId, params.studentId);
  }
}
