import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetCompletedBookIdsParams {

  const GetCompletedBookIdsParams({required this.userId});
  final String userId;
}

class GetCompletedBookIdsUseCase
    implements UseCase<Set<String>, GetCompletedBookIdsParams> {

  const GetCompletedBookIdsUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, Set<String>>> call(GetCompletedBookIdsParams params) {
    return _repository.getCompletedBookIds(params.userId);
  }
}
