import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetCompletedInlineActivitiesParams {
  final String userId;
  final String chapterId;

  const GetCompletedInlineActivitiesParams({
    required this.userId,
    required this.chapterId,
  });
}

class GetCompletedInlineActivitiesUseCase
    implements UseCase<List<String>, GetCompletedInlineActivitiesParams> {
  final BookRepository _repository;

  const GetCompletedInlineActivitiesUseCase(this._repository);

  @override
  Future<Either<Failure, List<String>>> call(GetCompletedInlineActivitiesParams params) {
    return _repository.getCompletedInlineActivities(
      userId: params.userId,
      chapterId: params.chapterId,
    );
  }
}
