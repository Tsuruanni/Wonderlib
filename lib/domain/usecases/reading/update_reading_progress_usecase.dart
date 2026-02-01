import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/reading_progress.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class UpdateReadingProgressParams {

  const UpdateReadingProgressParams({required this.progress});
  final ReadingProgress progress;
}

class UpdateReadingProgressUseCase
    implements UseCase<ReadingProgress, UpdateReadingProgressParams> {

  const UpdateReadingProgressUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, ReadingProgress>> call(UpdateReadingProgressParams params) {
    return _repository.updateReadingProgress(params.progress);
  }
}
