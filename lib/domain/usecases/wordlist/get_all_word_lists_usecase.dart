import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/word_list.dart';
import '../../repositories/word_list_repository.dart';
import '../usecase.dart';

class GetAllWordListsParams {

  const GetAllWordListsParams({
    this.category,
    this.isSystem,
  });
  final WordListCategory? category;
  final bool? isSystem;
}

class GetAllWordListsUseCase
    implements UseCase<List<WordList>, GetAllWordListsParams> {

  const GetAllWordListsUseCase(this._repository);
  final WordListRepository _repository;

  @override
  Future<Either<Failure, List<WordList>>> call(GetAllWordListsParams params) {
    return _repository.getAllWordLists(
      category: params.category,
      isSystem: params.isSystem,
    );
  }
}
