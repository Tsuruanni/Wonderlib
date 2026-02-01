import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetContinueReadingParams {
  final String userId;

  const GetContinueReadingParams({required this.userId});
}

class GetContinueReadingUseCase
    implements UseCase<List<Book>, GetContinueReadingParams> {
  final BookRepository _repository;

  const GetContinueReadingUseCase(this._repository);

  @override
  Future<Either<Failure, List<Book>>> call(GetContinueReadingParams params) {
    return _repository.getContinueReading(params.userId);
  }
}
