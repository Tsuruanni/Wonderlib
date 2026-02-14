import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book_quiz.dart';
import '../../repositories/book_quiz_repository.dart';
import '../usecase.dart';

class GetStudentQuizResultsParams {
  const GetStudentQuizResultsParams({required this.studentId});
  final String studentId;
}

class GetStudentQuizResultsUseCase
    implements UseCase<List<StudentQuizProgress>, GetStudentQuizResultsParams> {
  const GetStudentQuizResultsUseCase(this._repository);
  final BookQuizRepository _repository;

  @override
  Future<Either<Failure, List<StudentQuizProgress>>> call(
    GetStudentQuizResultsParams params,
  ) {
    return _repository.getStudentQuizResults(params.studentId);
  }
}
