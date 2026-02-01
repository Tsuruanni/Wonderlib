import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetWordsForListParams {
  final String listId;

  const GetWordsForListParams({required this.listId});
}

class GetWordsForListUseCase
    implements UseCase<List<VocabularyWord>, GetWordsForListParams> {
  final WordListRepository _repository;

  const GetWordsForListUseCase(this._repository);

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetWordsForListParams params) {
    return _repository.getWordsForList(params.listId);
  }
}
