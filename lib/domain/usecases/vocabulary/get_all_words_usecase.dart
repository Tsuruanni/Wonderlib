import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetAllWordsParams {
  final String? level;
  final List<String>? categories;
  final int page;
  final int pageSize;

  const GetAllWordsParams({
    this.level,
    this.categories,
    this.page = 1,
    this.pageSize = 50,
  });
}

class GetAllWordsUseCase implements UseCase<List<VocabularyWord>, GetAllWordsParams> {
  final VocabularyRepository _repository;

  const GetAllWordsUseCase(this._repository);

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
