import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetWordsForListParams {

  const GetWordsForListParams({required this.listId});
  final String listId;
}

class GetWordsForListUseCase
    implements UseCase<List<VocabularyWord>, GetWordsForListParams> {

  const GetWordsForListUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetWordsForListParams params) {
    return _repository.getWordsForList(params.listId);
  }
}
