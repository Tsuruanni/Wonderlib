import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetBookByIdParams {
  final String bookId;

  const GetBookByIdParams({required this.bookId});
}

class GetBookByIdUseCase implements UseCase<Book, GetBookByIdParams> {
  final BookRepository _repository;

  const GetBookByIdUseCase(this._repository);

  @override
  Future<Either<Failure, Book>> call(GetBookByIdParams params) {
    return _repository.getBookById(params.bookId);
  }
}
