import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book_quiz.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class GetBestQuizResultParams {
  const GetBestQuizResultParams({
    required this.userId,
    required this.bookId,
  });
  final String userId;
  final String bookId;
}

class GetBestQuizResultUseCase
    implements UseCase<BookQuizResult?, GetBestQuizResultParams> {
  const GetBestQuizResultUseCase(this._repository);
  final BookQuizRepository _repository;

  @override
  Future<Either<Failure, BookQuizResult?>> call(
    GetBestQuizResultParams params,
  ) {
    return _repository.getBestResult(
      userId: params.userId,
      bookId: params.bookId,
    );
  }
}
