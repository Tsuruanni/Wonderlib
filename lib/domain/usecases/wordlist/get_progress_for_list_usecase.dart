import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetProgressForListParams {
  final String userId;
  final String listId;

  const GetProgressForListParams({
    required this.userId,
    required this.listId,
  });
}

class GetProgressForListUseCase
    implements UseCase<UserWordListProgress?, GetProgressForListParams> {
  final WordListRepository _repository;

  const GetProgressForListUseCase(this._repository);

  @override
  Future<Either<Failure, UserWordListProgress?>> call(
      GetProgressForListParams params) {
    return _repository.getProgressForList(
      userId: params.userId,
      listId: params.listId,
    );
  }
}
