import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class SearchWordsParams {

  const SearchWordsParams({required this.query});
  final String query;
}

class SearchWordsUseCase implements UseCase<List<VocabularyWord>, SearchWordsParams> {

  const SearchWordsUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(SearchWordsParams params) {
    return _repository.searchWords(params.query);
  }
}
