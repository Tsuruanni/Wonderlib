import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class UpdateWordListProgressParams {

  const UpdateWordListProgressParams({required this.progress});
  final UserWordListProgress progress;
}

class UpdateWordListProgressUseCase
    implements UseCase<UserWordListProgress, UpdateWordListProgressParams> {

  const UpdateWordListProgressUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, UserWordListProgress>> call(
      UpdateWordListProgressParams params,) {
    return _repository.updateWordListProgress(params.progress);
  }
}
