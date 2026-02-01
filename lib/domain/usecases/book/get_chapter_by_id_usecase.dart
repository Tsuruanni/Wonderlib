import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/chapter.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetChapterByIdParams {
  final String chapterId;

  const GetChapterByIdParams({required this.chapterId});
}

class GetChapterByIdUseCase implements UseCase<Chapter, GetChapterByIdParams> {
  final BookRepository _repository;

  const GetChapterByIdUseCase(this._repository);

  @override
  Future<Either<Failure, Chapter>> call(GetChapterByIdParams params) {
    return _repository.getChapterById(params.chapterId);
  }
}
