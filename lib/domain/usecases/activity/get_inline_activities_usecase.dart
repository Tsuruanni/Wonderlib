import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/activity.dart';
import '../../repositories/book_repository.dart';
import '../usecase.dart';

class GetInlineActivitiesParams {

  const GetInlineActivitiesParams({required this.chapterId});
  final String chapterId;
}

class GetInlineActivitiesUseCase
    implements UseCase<List<InlineActivity>, GetInlineActivitiesParams> {

  const GetInlineActivitiesUseCase(this._repository);
  final BookRepository _repository;

  @override
  Future<Either<Failure, List<InlineActivity>>> call(GetInlineActivitiesParams params) {
    return _repository.getInlineActivities(params.chapterId);
  }
}
