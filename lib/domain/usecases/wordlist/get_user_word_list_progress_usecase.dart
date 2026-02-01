import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetUserWordListProgressParams {
  final String userId;

  const GetUserWordListProgressParams({required this.userId});
}

class GetUserWordListProgressUseCase
    implements UseCase<List<UserWordListProgress>, GetUserWordListProgressParams> {
  final WordListRepository _repository;

  const GetUserWordListProgressUseCase(this._repository);

  @override
  Future<Either<Failure, List<UserWordListProgress>>> call(
      GetUserWordListProgressParams params) {
    return _repository.getUserWordListProgress(params.userId);
  }
}
