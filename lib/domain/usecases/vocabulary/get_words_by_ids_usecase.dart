import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetWordsByIdsParams {

  const GetWordsByIdsParams({required this.ids});
  final List<String> ids;
}

class GetWordsByIdsUseCase implements UseCase<List<VocabularyWord>, GetWordsByIdsParams> {

  const GetWordsByIdsUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetWordsByIdsParams params) {
    return _repository.getWordsByIds(params.ids);
  }
}
