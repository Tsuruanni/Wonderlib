import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class UpdateWordProgressParams {

  const UpdateWordProgressParams({required this.progress});
  final VocabularyProgress progress;
}

class UpdateWordProgressUseCase
    implements UseCase<VocabularyProgress, UpdateWordProgressParams> {

  const UpdateWordProgressUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, VocabularyProgress>> call(UpdateWordProgressParams params) {
    return _repository.updateWordProgress(params.progress);
  }
}
