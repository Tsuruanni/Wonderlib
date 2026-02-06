import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class AddWordsBatchParams {
  const AddWordsBatchParams({
    required this.userId,
    required this.wordIds,
    this.immediate = false,
  });

  final String userId;
  final List<String> wordIds;
  final bool immediate;
}

/// Add multiple words to vocabulary in batch
/// Used for adding words after book completion or word list Phase 4 completion
class AddWordsBatchToVocabularyUseCase
    implements UseCase<List<VocabularyProgress>, AddWordsBatchParams> {
  const AddWordsBatchToVocabularyUseCase(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyProgress>>> call(
    AddWordsBatchParams params,
  ) {
    return _repository.addWordsToVocabularyBatch(
      userId: params.userId,
      wordIds: params.wordIds,
      immediate: params.immediate,
    );
  }
}
