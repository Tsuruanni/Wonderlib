import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/unit_assignment_item.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetUnitAssignmentItemsParams {
  const GetUnitAssignmentItemsParams({
    required this.scopeLpUnitId,
    required this.studentId,
  });
  final String scopeLpUnitId;
  final String studentId;
}

class GetUnitAssignmentItemsUseCase
    implements UseCase<List<UnitAssignmentItem>, GetUnitAssignmentItemsParams> {
  const GetUnitAssignmentItemsUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, List<UnitAssignmentItem>>> call(
    GetUnitAssignmentItemsParams params,
  ) {
    return _repository.getUnitAssignmentItems(params.scopeLpUnitId, params.studentId);
  }
}
