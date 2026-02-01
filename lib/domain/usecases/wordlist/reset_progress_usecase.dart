import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class ResetProgressParams {

  const ResetProgressParams({
    required this.userId,
    required this.listId,
  });
  final String userId;
  final String listId;
}

class ResetProgressUseCase implements UseCase<void, ResetProgressParams> {

  const ResetProgressUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, void>> call(ResetProgressParams params) {
    return _repository.resetProgress(
      userId: params.userId,
      listId: params.listId,
    );
  }
}
