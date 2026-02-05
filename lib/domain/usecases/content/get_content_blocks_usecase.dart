import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/content/content_block.dart';
import '../../repositories/content_block_repository.dart';
import '../usecase.dart';

class GetContentBlocksParams {
  const GetContentBlocksParams({required this.chapterId});
  final String chapterId;
}

class GetContentBlocksUseCase
    implements UseCase<List<ContentBlock>, GetContentBlocksParams> {
  const GetContentBlocksUseCase(this._repository);
  final ContentBlockRepository _repository;

  @override
  Future<Either<Failure, List<ContentBlock>>> call(
    GetContentBlocksParams params,
  ) {
    return _repository.getContentBlocks(params.chapterId);
  }
}
