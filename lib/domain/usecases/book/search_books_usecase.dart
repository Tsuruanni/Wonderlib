import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class SearchBooksParams {
  final String query;

  const SearchBooksParams({required this.query});
}

class SearchBooksUseCase implements UseCase<List<Book>, SearchBooksParams> {
  final BookRepository _repository;

  const SearchBooksUseCase(this._repository);

  @override
  Future<Either<Failure, List<Book>>> call(SearchBooksParams params) {
    return _repository.searchBooks(params.query);
  }
}
