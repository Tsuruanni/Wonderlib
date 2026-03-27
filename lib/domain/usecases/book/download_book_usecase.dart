import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_download_repository.dart';
import '../usecase.dart';

class DownloadBookParams {
  const DownloadBookParams({
    required this.bookId,
    required this.userId,
    this.includeAudio = false,
    this.onProgress,
  });

  final String bookId;
  final String userId;
  final bool includeAudio;
  final DownloadProgressCallback? onProgress;
}

class DownloadBookUseCase implements UseCase<bool, DownloadBookParams> {
  const DownloadBookUseCase(this._repository);

  final BookDownloadRepository _repository;

  @override
  Future<Either<Failure, bool>> call(DownloadBookParams params) {
    return _repository.downloadBook(
      params.bookId,
      userId: params.userId,
      includeAudio: params.includeAudio,
      onProgress: params.onProgress,
    );
  }
}
