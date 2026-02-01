import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/content_block_repository.dart';
import '../usecase.dart';

class CheckChapterUsesContentBlocksParams {
  const CheckChapterUsesContentBlocksParams({required this.chapterId});
  final String chapterId;
}

class CheckChapterUsesContentBlocksUseCase
    implements UseCase<bool, CheckChapterUsesContentBlocksParams> {
  const CheckChapterUsesContentBlocksUseCase(this._repository);
  final ContentBlockRepository _repository;

  @override
  Future<Either<Failure, bool>> call(
    CheckChapterUsesContentBlocksParams params,
  ) {
    return _repository.chapterUsesContentBlocks(params.chapterId);
  }
}
