import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class BookHasQuizParams {
  const BookHasQuizParams({required this.bookId});
  final String bookId;
}

class BookHasQuizUseCase implements UseCase<bool, BookHasQuizParams> {
  const BookHasQuizUseCase(this._repository);
  final BookQuizRepository _repository;

  @override
  Future<Either<Failure, bool>> call(BookHasQuizParams params) {
    return _repository.bookHasQuiz(params.bookId);
  }
}
