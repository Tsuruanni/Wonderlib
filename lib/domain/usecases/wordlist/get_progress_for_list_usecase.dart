import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetProgressForListParams {

  const GetProgressForListParams({
    required this.userId,
    required this.listId,
  });
  final String userId;
  final String listId;
}

class GetProgressForListUseCase
    implements UseCase<UserWordListProgress?, GetProgressForListParams> {

  const GetProgressForListUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, UserWordListProgress?>> call(
      GetProgressForListParams params,) {
    return _repository.getProgressForList(
      userId: params.userId,
      listId: params.listId,
    );
  }
}
