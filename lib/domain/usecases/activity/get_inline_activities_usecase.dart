import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetInlineActivitiesParams {
  final String chapterId;

  const GetInlineActivitiesParams({required this.chapterId});
}

class GetInlineActivitiesUseCase
    implements UseCase<List<InlineActivity>, GetInlineActivitiesParams> {
  final BookRepository _repository;

  const GetInlineActivitiesUseCase(this._repository);

  @override
  Future<Either<Failure, List<InlineActivity>>> call(GetInlineActivitiesParams params) {
    return _repository.getInlineActivities(params.chapterId);
  }
}
