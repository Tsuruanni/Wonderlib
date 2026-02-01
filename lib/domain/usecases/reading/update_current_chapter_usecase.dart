import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class UpdateCurrentChapterParams {

  const UpdateCurrentChapterParams({
    required this.userId,
    required this.bookId,
    required this.chapterId,
  });
  final String userId;
  final String bookId;
  final String chapterId;
}

class UpdateCurrentChapterUseCase
    implements UseCase<void, UpdateCurrentChapterParams> {

  const UpdateCurrentChapterUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, void>> call(UpdateCurrentChapterParams params) {
    return _repository.updateCurrentChapter(
      userId: params.userId,
      bookId: params.bookId,
      chapterId: params.chapterId,
    );
  }
}
