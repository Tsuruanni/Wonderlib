import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/chapter.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetChaptersParams {

  const GetChaptersParams({required this.bookId});
  final String bookId;
}

class GetChaptersUseCase implements UseCase<List<Chapter>, GetChaptersParams> {

  const GetChaptersUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<Chapter>>> call(GetChaptersParams params) {
    return _repository.getChapters(params.bookId);
  }
}
