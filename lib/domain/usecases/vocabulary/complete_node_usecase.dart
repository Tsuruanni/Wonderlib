import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class CompleteNodeParams {
  const CompleteNodeParams({
    required this.userId,
    required this.unitId,
    required this.nodeType,
  });

  final String userId;
  final String unitId;
  final String nodeType;
}

class CompleteNodeUseCase implements UseCase<void, CompleteNodeParams> {
  const CompleteNodeUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, void>> call(CompleteNodeParams params) {
    return _repository.completeNode(
      userId: params.userId,
      unitId: params.unitId,
      nodeType: params.nodeType,
    );
  }
}
