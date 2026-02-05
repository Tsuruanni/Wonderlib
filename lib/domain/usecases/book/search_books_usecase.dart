import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class SearchBooksParams {

  const SearchBooksParams({required this.query});
  final String query;
}

class SearchBooksUseCase implements UseCase<List<Book>, SearchBooksParams> {

  const SearchBooksUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<Book>>> call(SearchBooksParams params) {
    return _repository.searchBooks(params.query);
  }
}
