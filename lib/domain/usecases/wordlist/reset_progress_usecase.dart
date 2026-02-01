import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class ResetProgressParams {
  final String userId;
  final String listId;

  const ResetProgressParams({
    required this.userId,
    required this.listId,
  });
}

class ResetProgressUseCase implements UseCase<void, ResetProgressParams> {
  final WordListRepository _repository;

  const ResetProgressUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ResetProgressParams params) {
    return _repository.resetProgress(
      userId: params.userId,
      listId: params.listId,
    );
  }
}
