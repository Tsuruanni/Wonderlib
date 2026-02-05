import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class CheckReadTodayParams {
  const CheckReadTodayParams({required this.userId});
  final String userId;
}

class CheckReadTodayUseCase implements UseCase<bool, CheckReadTodayParams> {
  const CheckReadTodayUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, bool>> call(CheckReadTodayParams params) {
    return _repository.hasReadToday(params.userId);
  }
}
