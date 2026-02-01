import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetBooksParams {
  final String? level;
  final String? genre;
  final String? ageGroup;
  final int page;
  final int pageSize;

  const GetBooksParams({
    this.level,
    this.genre,
    this.ageGroup,
    this.page = 1,
    this.pageSize = 20,
  });
}

class GetBooksUseCase implements UseCase<List<Book>, GetBooksParams> {
  final BookRepository _repository;

  const GetBooksUseCase(this._repository);

  @override
  Future<Either<Failure, List<Book>>> call(GetBooksParams params) {
    return _repository.getBooks(
      level: params.level,
      genre: params.genre,
      ageGroup: params.ageGroup,
      page: params.page,
      pageSize: params.pageSize,
    );
  }
}
