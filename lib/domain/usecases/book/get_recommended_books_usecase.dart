import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetRecommendedBooksParams {
  final String userId;

  const GetRecommendedBooksParams({required this.userId});
}

class GetRecommendedBooksUseCase
    implements UseCase<List<Book>, GetRecommendedBooksParams> {
  final BookRepository _repository;

  const GetRecommendedBooksUseCase(this._repository);

  @override
  Future<Either<Failure, List<Book>>> call(GetRecommendedBooksParams params) {
    return _repository.getRecommendedBooks(params.userId);
  }
}
