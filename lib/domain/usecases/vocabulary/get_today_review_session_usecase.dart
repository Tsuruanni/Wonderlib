import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/daily_review_session.dart';
import '../../repositories/vocabulary_repository.dart';
import '../usecase.dart';

class GetTodayReviewSessionParams {
  const GetTodayReviewSessionParams({required this.userId});

  final String userId;
}

/// Get today's review session if user has already completed it
class GetTodayReviewSessionUseCase
    implements UseCase<DailyReviewSession?, GetTodayReviewSessionParams> {
  const GetTodayReviewSessionUseCase(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Either<Failure, DailyReviewSession?>> call(
    GetTodayReviewSessionParams params,
  ) {
    return _repository.getTodayReviewSession(params.userId);
  }
}
