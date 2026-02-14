import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book_quiz.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class GetUserQuizResultsParams {
  const GetUserQuizResultsParams({
    required this.userId,
    required this.bookId,
  });
  final String userId;
  final String bookId;
}

class GetUserQuizResultsUseCase
    implements UseCase<List<BookQuizResult>, GetUserQuizResultsParams> {
  const GetUserQuizResultsUseCase(this._repository);
  final BookQuizRepository _repository;

  @override
  Future<Either<Failure, List<BookQuizResult>>> call(
    GetUserQuizResultsParams params,
  ) {
    return _repository.getUserQuizResults(
      userId: params.userId,
      bookId: params.bookId,
    );
  }
}
