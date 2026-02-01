import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/chapter.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetChaptersParams {
  final String bookId;

  const GetChaptersParams({required this.bookId});
}

class GetChaptersUseCase implements UseCase<List<Chapter>, GetChaptersParams> {
  final BookRepository _repository;

  const GetChaptersUseCase(this._repository);

  @override
  Future<Either<Failure, List<Chapter>>> call(GetChaptersParams params) {
    return _repository.getChapters(params.bookId);
  }
}
