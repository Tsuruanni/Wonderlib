import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetWordListByIdParams {
  final String listId;

  const GetWordListByIdParams({required this.listId});
}

class GetWordListByIdUseCase
    implements UseCase<WordList, GetWordListByIdParams> {
  final WordListRepository _repository;

  const GetWordListByIdUseCase(this._repository);

  @override
  Future<Either<Failure, WordList>> call(GetWordListByIdParams params) {
    return _repository.getWordListById(params.listId);
  }
}
