import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/book_cache_store.dart';
import '../../core/services/book_download_service.dart';
import '../../core/services/file_cache_service.dart';
import '../../domain/entities/book.dart';

part 'book_download_provider.g.dart';

// ============================================================================
// Download status for a specific book
// ============================================================================

/// Returns the download status string for a book, or `null` if the book
/// has never been cached. Possible values: 'pending', 'downloading',
/// 'complete', 'failed'.
@riverpod
Future<String?> bookDownloadStatus(
  BookDownloadStatusRef ref,
  String bookId,
) async {
  final cacheStore = ref.watch(bookCacheStoreProvider);
  return cacheStore.getDownloadStatus(bookId);
}

// ============================================================================
// Active download progress tracking
// ============================================================================

/// Tracks active download progress as a map of bookId to progress (0.0–1.0).
///
/// UI widgets can watch this provider to show real-time download progress
/// bars. Entries are removed when the download completes or fails.
@riverpod
class ActiveDownloads extends _$ActiveDownloads {
  @override
  Map<String, double> build() => {};

  /// Update progress for a book download.
  void updateProgress(String bookId, double progress) {
    state = {...state, bookId: progress};
  }

  /// Remove a download entry (called on completion or cancellation).
  void removeDownload(String bookId) {
    state = Map<String, double>.from(state)..remove(bookId);
  }
}

// ============================================================================
// Book downloader (start/remove downloads)
// ============================================================================

/// Manages book download lifecycle: starting new downloads and removing
/// cached books.
@riverpod
class BookDownloader extends _$BookDownloader {
  @override
  FutureOr<void> build() {}

  /// Start downloading a book for offline reading.
  ///
  /// Returns `true` on success, `false` on failure. Updates the
  /// [activeDownloadsProvider] with real-time progress and invalidates
  /// [bookDownloadStatusProvider] on completion.
  Future<bool> downloadBook(
    String bookId, {
    required String userId,
    bool includeAudio = false,
  }) async {
    final service = ref.read(bookDownloadServiceProvider);
    final activeDownloads = ref.read(activeDownloadsProvider.notifier);

    // Initialize progress tracking
    activeDownloads.updateProgress(bookId, 0.0);

    final success = await service.downloadBook(
      bookId,
      userId: userId,
      includeAudio: includeAudio,
      onProgress: (progress, _) {
        activeDownloads.updateProgress(bookId, progress);
      },
    );

    // Clean up active download tracking
    activeDownloads.removeDownload(bookId);

    // Invalidate status so watchers pick up the new state
    ref.invalidate(bookDownloadStatusProvider(bookId));
    ref.invalidate(downloadedBooksProvider);

    return success;
  }

  /// Remove a downloaded book and all its cached files.
  Future<void> removeDownload(String bookId) async {
    final fileCacheService = ref.read(fileCacheServiceProvider);
    final cacheStore = ref.read(bookCacheStoreProvider);

    // Delete on-disk files first
    await fileCacheService.deleteBookFiles(bookId);

    // Delete DB records (cascades to chapters, content blocks, etc.)
    await cacheStore.deleteBook(bookId);

    // Invalidate status so watchers update
    ref.invalidate(bookDownloadStatusProvider(bookId));
    ref.invalidate(downloadedBooksProvider);
  }
}

// ============================================================================
// All downloaded books (for management screen)
// ============================================================================

/// Information about a single downloaded book.
class DownloadedBookInfo {
  const DownloadedBookInfo({
    required this.bookId,
    required this.book,
    required this.cachedAt,
    required this.downloadStatus,
    required this.fileSizeBytes,
  });

  final String bookId;
  final Book book;
  final String cachedAt;
  final String downloadStatus;
  final int fileSizeBytes;

  /// Human-readable file size (e.g. "12.3 MB", "456 KB").
  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Returns all downloaded books with their metadata and cache sizes.
///
/// Useful for building a "Downloaded Books" management screen where users
/// can see storage usage and delete cached books.
@riverpod
Future<List<DownloadedBookInfo>> downloadedBooks(
  DownloadedBooksRef ref,
) async {
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final allCached = await cacheStore.getAllCachedBooks();

  final results = <DownloadedBookInfo>[];
  for (final entry in allCached) {
    final book = entry['book'] as Book;
    final status = entry['download_status'] as String;

    // Only include books that have been fully or partially downloaded
    if (status == 'complete' || status == 'failed' || status == 'downloading') {
      final size = await cacheStore.getBookCacheSize(book.id);
      results.add(
        DownloadedBookInfo(
          bookId: book.id,
          book: book,
          cachedAt: entry['cached_at'] as String,
          downloadStatus: status,
          fileSizeBytes: size,
        ),
      );
    }
  }

  return results;
}
