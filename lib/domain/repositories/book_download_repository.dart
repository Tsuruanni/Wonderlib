import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';

/// Progress callback for download operations.
///
/// [progress] ranges from 0.0 to 1.0. [stepDescription] provides a
/// human-readable label for the current step.
typedef DownloadProgressCallback = void Function(
  double progress,
  String stepDescription,
);

/// Repository interface for book download/removal operations.
///
/// Abstracts the underlying download service and cache management so that
/// UseCases and providers never touch data-layer services directly.
abstract class BookDownloadRepository {
  /// Download all data needed to read [bookId] offline.
  ///
  /// Returns `Right(true)` on success, `Left(Failure)` on error.
  /// [onProgress] is called periodically with values in 0.0-1.0.
  Future<Either<Failure, bool>> downloadBook(
    String bookId, {
    required String userId,
    bool includeAudio = false,
    DownloadProgressCallback? onProgress,
  });

  /// Remove a downloaded book and all its cached files.
  Future<Either<Failure, void>> removeDownload(String bookId);
}
