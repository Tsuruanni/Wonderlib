import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/vocabulary.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetDueForReviewParams {

  const GetDueForReviewParams({required this.userId});
  final String userId;
}

class GetDueForReviewUseCase
    implements UseCase<List<VocabularyWord>, GetDueForReviewParams> {

  const GetDueForReviewUseCase(this._repository);
  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, List<VocabularyWord>>> call(GetDueForReviewParams params) {
    return _repository.getDueForReview(params.userId);
  }
}
