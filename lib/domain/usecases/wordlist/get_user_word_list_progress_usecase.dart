import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetUserWordListProgressParams {

  const GetUserWordListProgressParams({required this.userId});
  final String userId;
}

class GetUserWordListProgressUseCase
    implements UseCase<List<UserWordListProgress>, GetUserWordListProgressParams> {

  const GetUserWordListProgressUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, List<UserWordListProgress>>> call(
      GetUserWordListProgressParams params,) {
    return _repository.getUserWordListProgress(params.userId);
  }
}
