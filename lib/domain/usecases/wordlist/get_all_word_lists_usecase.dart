import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetAllWordListsParams {
  final WordListCategory? category;
  final bool? isSystem;

  const GetAllWordListsParams({
    this.category,
    this.isSystem,
  });
}

class GetAllWordListsUseCase
    implements UseCase<List<WordList>, GetAllWordListsParams> {
  final WordListRepository _repository;

  const GetAllWordListsUseCase(this._repository);

  @override
  Future<Either<Failure, List<WordList>>> call(GetAllWordListsParams params) {
    return _repository.getAllWordLists(
      category: params.category,
      isSystem: params.isSystem,
    );
  }
}
