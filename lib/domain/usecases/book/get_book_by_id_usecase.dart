import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetBookByIdParams {

  const GetBookByIdParams({required this.bookId});
  final String bookId;
}

class GetBookByIdUseCase implements UseCase<Book, GetBookByIdParams> {

  const GetBookByIdUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, Book>> call(GetBookByIdParams params) {
    return _repository.getBookById(params.bookId);
  }
}
