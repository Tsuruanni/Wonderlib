import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class UpdateWordListProgressParams {
  final UserWordListProgress progress;

  const UpdateWordListProgressParams({required this.progress});
}

class UpdateWordListProgressUseCase
    implements UseCase<UserWordListProgress, UpdateWordListProgressParams> {
  final WordListRepository _repository;

  const UpdateWordListProgressUseCase(this._repository);

  @override
  Future<Either<Failure, UserWordListProgress>> call(
      UpdateWordListProgressParams params) {
    return _repository.updateWordListProgress(params.progress);
  }
}
