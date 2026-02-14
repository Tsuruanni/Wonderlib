import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book_quiz.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class GetQuizForBookParams {
  const GetQuizForBookParams({required this.bookId});
  final String bookId;
}

class GetQuizForBookUseCase
    implements UseCase<BookQuiz?, GetQuizForBookParams> {
  const GetQuizForBookUseCase(this._repository);
  final BookQuizRepository _repository;

  @override
  Future<Either<Failure, BookQuiz?>> call(GetQuizForBookParams params) {
    return _repository.getQuizForBook(params.bookId);
  }
}
