import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetAllWordsParams {

  const GetAllWordsParams({
    this.level,
    this.categories,
    this.page = 1,
    this.pageSize = 50,
  });
  final String? level;
  final List<String>? categories;
  final int page;
  final int pageSize;
}

class GetAllWordsUseCase implements UseCase<List<VocabularyWord>, GetAllWordsParams> {

  const GetAllWordsUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetAllWordsParams params) {
    return _repository.getAllWords(
      level: params.level,
      categories: params.categories,
      page: params.page,
      pageSize: params.pageSize,
    );
  }
}
