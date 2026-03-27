import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/services/book_cache_store.dart';
import '../../core/services/book_download_service.dart'
    hide DownloadProgressCallback;
import '../../core/services/file_cache_service.dart';
import '../../domain/repositories/book_download_repository.dart';

/// Implementation of [BookDownloadRepository] that delegates to the existing
/// [BookDownloadService], [FileCacheService], and [BookCacheStore].
class BookDownloadRepositoryImpl implements BookDownloadRepository {
  const BookDownloadRepositoryImpl({
    required BookDownloadService downloadService,
    required FileCacheService fileCacheService,
    required BookCacheStore cacheStore,
  })  : _downloadService = downloadService,
        _fileCacheService = fileCacheService,
        _cacheStore = cacheStore;

  final BookDownloadService _downloadService;
  final FileCacheService _fileCacheService;
  final BookCacheStore _cacheStore;

  @override
  Future<Either<Failure, bool>> downloadBook(
    String bookId, {
    required String userId,
    bool includeAudio = false,
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      final success = await _downloadService.downloadBook(
        bookId,
        userId: userId,
        includeAudio: includeAudio,
        onProgress: onProgress != null
            ? (progress, step) => onProgress(progress, step)
            : null,
      );
      return Right(success);
    } catch (e) {
      debugPrint('BookDownloadRepositoryImpl: downloadBook failed: $e');
      return const Left(
        CacheFailure('Failed to download book for offline reading'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> removeDownload(String bookId) async {
    try {
      // Delete on-disk files first
      await _fileCacheService.deleteBookFiles(bookId);

      // Delete DB records (cascades to chapters, content blocks, etc.)
      await _cacheStore.deleteBook(bookId);

      return const Right(null);
    } catch (e) {
      debugPrint('BookDownloadRepositoryImpl: removeDownload failed: $e');
      return const Left(
        CacheFailure('Failed to remove downloaded book'),
      );
    }
  }
}
