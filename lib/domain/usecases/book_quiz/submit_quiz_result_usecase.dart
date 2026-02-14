import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book_quiz.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class SubmitQuizResultParams {
  const SubmitQuizResultParams({required this.result});
  final BookQuizResult result;
}

class SubmitQuizResultUseCase
    implements UseCase<BookQuizResult, SubmitQuizResultParams> {
  const SubmitQuizResultUseCase(this._repository);
  final BookQuizRepository _repository;

  @override
  Future<Either<Failure, BookQuizResult>> call(SubmitQuizResultParams params) {
    return _repository.submitQuizResult(params.result);
  }
}
