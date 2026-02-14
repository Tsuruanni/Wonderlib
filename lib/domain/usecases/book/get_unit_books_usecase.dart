import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/unit_book.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetUnitBooksParams {
  const GetUnitBooksParams({required this.userId});
  final String userId;
}

class GetUnitBooksUseCase
    implements UseCase<List<UnitBook>, GetUnitBooksParams> {
  const GetUnitBooksUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<UnitBook>>> call(GetUnitBooksParams params) {
    return _repository.getUnitBooks(params.userId);
  }
}
