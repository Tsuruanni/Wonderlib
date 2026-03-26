import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetBooksByIdsParams {
  const GetBooksByIdsParams({required this.ids});
  final List<String> ids;
}

class GetBooksByIdsUseCase implements UseCase<List<Book>, GetBooksByIdsParams> {
  const GetBooksByIdsUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<Book>>> call(GetBooksByIdsParams params) {
    return _repository.getBooksByIds(params.ids);
  }
}
