import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetRecommendedBooksParams {

  const GetRecommendedBooksParams({required this.userId});
  final String userId;
}

class GetRecommendedBooksUseCase
    implements UseCase<List<Book>, GetRecommendedBooksParams> {

  const GetRecommendedBooksUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<Book>>> call(GetRecommendedBooksParams params) {
    return _repository.getRecommendedBooks(params.userId);
  }
}
