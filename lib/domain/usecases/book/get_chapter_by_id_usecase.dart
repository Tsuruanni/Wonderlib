import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/chapter.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetChapterByIdParams {

  const GetChapterByIdParams({required this.chapterId});
  final String chapterId;
}

class GetChapterByIdUseCase implements UseCase<Chapter, GetChapterByIdParams> {

  const GetChapterByIdUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, Chapter>> call(GetChapterByIdParams params) {
    return _repository.getChapterById(params.chapterId);
  }
}
