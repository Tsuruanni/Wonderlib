import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetContinueReadingParams {

  const GetContinueReadingParams({required this.userId});
  final String userId;
}

class GetContinueReadingUseCase
    implements UseCase<List<Book>, GetContinueReadingParams> {

  const GetContinueReadingUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<Book>>> call(GetContinueReadingParams params) {
    return _repository.getContinueReading(params.userId);
  }
}
