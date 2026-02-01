import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class UpdateReadingProgressParams {
  final ReadingProgress progress;

  const UpdateReadingProgressParams({required this.progress});
}

class UpdateReadingProgressUseCase
    implements UseCase<ReadingProgress, UpdateReadingProgressParams> {
  final BookRepository _repository;

  const UpdateReadingProgressUseCase(this._repository);

  @override
  Future<Either<Failure, ReadingProgress>> call(UpdateReadingProgressParams params) {
    return _repository.updateReadingProgress(params.progress);
  }
}
