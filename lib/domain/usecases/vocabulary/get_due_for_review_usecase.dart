import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetDueForReviewParams {
  final String userId;

  const GetDueForReviewParams({required this.userId});
}

class GetDueForReviewUseCase
    implements UseCase<List<VocabularyWord>, GetDueForReviewParams> {
  final VocabularyRepository _repository;

  const GetDueForReviewUseCase(this._repository);

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetDueForReviewParams params) {
    return _repository.getDueForReview(params.userId);
  }
}
