import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class SearchWordsParams {
  final String query;

  const SearchWordsParams({required this.query});
}

class SearchWordsUseCase implements UseCase<List<VocabularyWord>, SearchWordsParams> {
  final VocabularyRepository _repository;

  const SearchWordsUseCase(this._repository);

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(SearchWordsParams params) {
    return _repository.searchWords(params.query);
  }
}
