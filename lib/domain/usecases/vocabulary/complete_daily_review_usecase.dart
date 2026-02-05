import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/daily_review_session.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class CompleteDailyReviewParams {
  const CompleteDailyReviewParams({
    required this.userId,
    required this.wordsReviewed,
    required this.correctCount,
    required this.incorrectCount,
  });

  final String userId;
  final int wordsReviewed;
  final int correctCount;
  final int incorrectCount;
}

/// Complete a daily review session and award XP
class CompleteDailyReviewUseCase
    implements UseCase<DailyReviewResult, CompleteDailyReviewParams> {
  const CompleteDailyReviewUseCase(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, DailyReviewResult>> call(
    CompleteDailyReviewParams params,
  ) {
    return _repository.completeDailyReview(
      userId: params.userId,
      wordsReviewed: params.wordsReviewed,
      correctCount: params.correctCount,
      incorrectCount: params.incorrectCount,
    );
  }
}
