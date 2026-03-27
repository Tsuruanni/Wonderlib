import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/book_download_repository.dart';
import '../usecase.dart';

class RemoveBookDownloadParams {
  const RemoveBookDownloadParams({required this.bookId});

  final String bookId;
}

class RemoveBookDownloadUseCase
    implements UseCase<void, RemoveBookDownloadParams> {
  const RemoveBookDownloadUseCase(this._repository);

  final BookDownloadRepository _repository;

  @override
  Future<Either<Failure, void>> call(RemoveBookDownloadParams params) {
    return _repository.removeDownload(params.bookId);
  }
}
