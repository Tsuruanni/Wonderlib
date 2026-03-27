import 'package:flutter/foundation.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/repositories/book_quiz_repository.dart';
import '../../domain/repositories/content_block_repository.dart';
import '../../presentation/providers/repository_providers.dart';
import 'book_cache_store.dart';
import 'file_cache_service.dart';

part 'book_download_service.g.dart';

/// Callback signature for download progress updates.
///
/// [progress] ranges from 0.0 to 1.0. [stepDescription] provides a
/// human-readable label for the current step (e.g. "Downloading chapter 2/5").
typedef DownloadProgressCallback = void Function(
  double progress,
  String stepDescription,
);

/// Orchestrates downloading all book data for offline reading.
///
/// Calling [downloadBook] fetches every artifact needed to read a book
/// offline — metadata, chapters, content blocks, activities, quizzes,
/// vocabulary words, images, and optionally audio — storing them via
/// [BookCacheStore] and [FileCacheService].
///
/// The download is **resumable**: re-running [downloadBook] on a partially
/// cached book skips already-downloaded files (the [FileCacheService]
/// cache-aside pattern returns immediately for files already on disk).
class BookDownloadService {
  BookDownloadService({
    required BookRepository bookRepo,
    required ContentBlockRepository contentBlockRepo,
    required BookQuizRepository quizRepo,
    required ActivityRepository activityRepo,
    required BookCacheStore cacheStore,
    required FileCacheService fileCacheService,
  })  : _bookRepo = bookRepo,
        _contentBlockRepo = contentBlockRepo,
        _quizRepo = quizRepo,
        _activityRepo = activityRepo,
        _cacheStore = cacheStore,
        _fileCacheService = fileCacheService;

  final BookRepository _bookRepo;
  final ContentBlockRepository _contentBlockRepo;
  final BookQuizRepository _quizRepo;
  final ActivityRepository _activityRepo;
  final BookCacheStore _cacheStore;
  final FileCacheService _fileCacheService;

  /// Download all data needed to read [bookId] offline.
  ///
  /// Returns `true` on success, `false` if any critical step fails. On
  /// failure the download status is set to `'failed'` but partial cache
  /// is retained so that a retry only re-downloads missing pieces.
  ///
  /// Set [includeAudio] to download chapter audio files as well (can be
  /// large). [onProgress] is called periodically with values in 0.0–1.0.
  Future<bool> downloadBook(
    String bookId, {
    required String userId,
    bool includeAudio = false,
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // -----------------------------------------------------------------
      // Step 1: Fetch book metadata (triggers cache-aside save)
      // -----------------------------------------------------------------
      onProgress?.call(0.0, 'Fetching book metadata');
      final bookResult = await _bookRepo.getBookById(bookId);
      final book = bookResult.fold(
        (failure) => throw Exception('Failed to fetch book: ${failure.message}'),
        (book) => book,
      );

      // -----------------------------------------------------------------
      // Step 2: Mark download as 'downloading'
      // -----------------------------------------------------------------
      await _cacheStore.setDownloadStatus(bookId, 'downloading');

      // -----------------------------------------------------------------
      // Step 3: Fetch all chapters (triggers cache-aside save)
      // -----------------------------------------------------------------
      onProgress?.call(0.05, 'Fetching chapters');
      final chaptersResult = await _bookRepo.getChapters(bookId);
      final chapters = chaptersResult.fold(
        (failure) =>
            throw Exception('Failed to fetch chapters: ${failure.message}'),
        (chapters) => chapters,
      );

      // Collect all vocabulary word IDs from inline activities across chapters.
      final allVocabIds = <String>{};

      // -----------------------------------------------------------------
      // Step 4: Process each chapter
      // -----------------------------------------------------------------
      final totalChapters = chapters.length;
      for (var i = 0; i < totalChapters; i++) {
        final chapter = chapters[i];
        final chapterProgress = 0.10 + (0.60 * (i / totalChapters));
        onProgress?.call(
          chapterProgress,
          'Processing chapter ${i + 1}/$totalChapters',
        );

        // 4a. Content blocks (if chapter uses them)
        if (chapter.useContentBlocks) {
          await _downloadContentBlocks(bookId, chapter.id, includeAudio);
        }

        // 4b. Inline activities (triggers cache-aside save)
        final inlineResult =
            await _bookRepo.getInlineActivities(chapter.id);
        inlineResult.fold((_) {}, (activities) {
          // Collect vocabulary word IDs from activities
          for (final activity in activities) {
            allVocabIds.addAll(activity.vocabularyWords);
          }
        });

        // 4c. Legacy activities (triggers cache-aside save)
        await _activityRepo.getActivitiesByChapter(chapter.id);

        // 4d. Download chapter images
        for (final imageUrl in chapter.imageUrls) {
          await _safeDownloadFile(imageUrl, bookId, 'image');
        }

        // 4e. Download chapter audio if requested
        if (includeAudio && chapter.audioUrl != null) {
          await _safeDownloadFile(chapter.audioUrl!, bookId, 'audio');
        }
      }

      // -----------------------------------------------------------------
      // Step 5: Download book cover image
      // -----------------------------------------------------------------
      onProgress?.call(0.75, 'Downloading book cover');
      if (book.coverUrl != null) {
        await _safeDownloadFile(book.coverUrl!, bookId, 'image');
      }

      // -----------------------------------------------------------------
      // Step 6: Fetch book quiz (triggers cache-aside save)
      // -----------------------------------------------------------------
      onProgress?.call(0.80, 'Fetching book quiz');
      await _quizRepo.getQuizForBook(bookId);

      // -----------------------------------------------------------------
      // Step 7: Batch-fetch vocabulary words from Supabase and cache
      // -----------------------------------------------------------------
      if (allVocabIds.isNotEmpty) {
        onProgress?.call(0.85, 'Downloading vocabulary');
        await _downloadVocabularyWords(bookId, allVocabIds);
      }

      // -----------------------------------------------------------------
      // Step 8: Fetch reading progress (triggers cache-aside save)
      // -----------------------------------------------------------------
      onProgress?.call(0.90, 'Fetching reading progress');
      await _bookRepo.getReadingProgress(userId: userId, bookId: bookId);

      // -----------------------------------------------------------------
      // Step 9: Fetch completed activities per chapter
      // -----------------------------------------------------------------
      onProgress?.call(0.93, 'Fetching completed activities');
      for (final chapter in chapters) {
        await _bookRepo.getCompletedInlineActivities(
          userId: userId,
          chapterId: chapter.id,
        );
      }

      // -----------------------------------------------------------------
      // Step 10: Mark download as complete
      // -----------------------------------------------------------------
      onProgress?.call(1.0, 'Download complete');
      await _cacheStore.setDownloadStatus(bookId, 'complete');

      return true;
    } catch (e) {
      debugPrint('BookDownloadService: download failed for $bookId: $e');
      // Mark as failed but keep partial cache for resume.
      try {
        await _cacheStore.setDownloadStatus(bookId, 'failed');
      } catch (_) {}
      return false;
    }
  }

  // ======================================================================
  // PRIVATE HELPERS
  // ======================================================================

  /// Download content blocks for a chapter and cache their media files.
  Future<void> _downloadContentBlocks(
    String bookId,
    String chapterId,
    bool includeAudio,
  ) async {
    final blocksResult = await _contentBlockRepo.getContentBlocks(chapterId);
    blocksResult.fold((_) {}, (blocks) async {
      for (final block in blocks) {
        // Download images from content blocks
        if (block.hasImage) {
          await _safeDownloadFile(block.imageUrl!, bookId, 'image');
        }
        // Download per-block audio if requested
        if (includeAudio && block.hasAudio) {
          await _safeDownloadFile(block.audioUrl!, bookId, 'audio');
        }
      }
    });
  }

  /// Batch-fetch vocabulary words from Supabase and save to cache.
  ///
  /// VocabularyRepository is not wrapped with a cached layer, so we query
  /// Supabase directly for the vocabulary_words table.
  Future<void> _downloadVocabularyWords(
    String bookId,
    Set<String> vocabIds,
  ) async {
    try {
      // Supabase .inFilter has a practical limit; batch in groups of 50.
      final idList = vocabIds.toList();
      final allRows = <Map<String, dynamic>>[];

      for (var start = 0; start < idList.length; start += 50) {
        final end =
            (start + 50 > idList.length) ? idList.length : start + 50;
        final batch = idList.sublist(start, end);
        final rows = await Supabase.instance.client
            .from(DbTables.vocabularyWords)
            .select()
            .inFilter('id', batch);
        allRows.addAll(List<Map<String, dynamic>>.from(rows));
      }

      if (allRows.isNotEmpty) {
        await _cacheStore.saveVocabularyWords(bookId, allRows);
      }
    } catch (e) {
      // Non-critical — vocabulary can be fetched later.
      debugPrint(
        'BookDownloadService: vocabulary download failed for $bookId: $e',
      );
    }
  }

  /// Download a single file, ignoring errors (non-critical for download).
  Future<void> _safeDownloadFile(
    String url,
    String bookId,
    String fileType,
  ) async {
    try {
      await _fileCacheService.getOrDownload(url, bookId, fileType);
    } catch (e) {
      debugPrint('BookDownloadService: file download failed: $url — $e');
    }
  }
}

@Riverpod(keepAlive: true)
BookDownloadService bookDownloadService(BookDownloadServiceRef ref) {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final contentBlockRepo = ref.watch(contentBlockRepositoryProvider);
  final quizRepo = ref.watch(bookQuizRepositoryProvider);
  final activityRepo = ref.watch(activityRepositoryProvider);
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final fileCache = ref.watch(fileCacheServiceProvider);
  return BookDownloadService(
    bookRepo: bookRepo,
    contentBlockRepo: contentBlockRepo,
    quizRepo: quizRepo,
    activityRepo: activityRepo,
    cacheStore: cacheStore,
    fileCacheService: fileCache,
  );
}
