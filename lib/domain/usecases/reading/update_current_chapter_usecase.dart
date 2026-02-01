import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class UpdateCurrentChapterParams {
  final String userId;
  final String bookId;
  final String chapterId;

  const UpdateCurrentChapterParams({
    required this.userId,
    required this.bookId,
    required this.chapterId,
  });
}

class UpdateCurrentChapterUseCase
    implements UseCase<void, UpdateCurrentChapterParams> {
  final BookRepository _repository;

  const UpdateCurrentChapterUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(UpdateCurrentChapterParams params) {
    return _repository.updateCurrentChapter(
      userId: params.userId,
      bookId: params.bookId,
      chapterId: params.chapterId,
    );
  }
}
