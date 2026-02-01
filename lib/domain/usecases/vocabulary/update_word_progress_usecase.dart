import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class UpdateWordProgressParams {
  final VocabularyProgress progress;

  const UpdateWordProgressParams({required this.progress});
}

class UpdateWordProgressUseCase
    implements UseCase<VocabularyProgress, UpdateWordProgressParams> {
  final VocabularyRepository _repository;

  const UpdateWordProgressUseCase(this._repository);

  @override
  Future<Either<Failure, VocabularyProgress>> call(UpdateWordProgressParams params) {
    return _repository.updateWordProgress(params.progress);
  }
}
