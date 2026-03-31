import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/repositories/book_repository.dart';
import '../supabase/supabase_book_repository.dart';

/// Cached wrapper around [SupabaseBookRepository].
///
/// Implements three strategies depending on the method:
///
/// **Cache-aside** — Check local cache first, fall back to remote on miss,
/// then write the remote result to cache for next time.
///
/// **Write-through** — Write to both cache and remote when online.
/// When offline, write to cache only with `isDirty: true` so the sync
/// service can replay later.
///
/// **Pass-through** — Always delegate to remote. Used for aggregated or
/// listing endpoints that are not worth caching.
class CachedBookRepository implements BookRepository {
  CachedBookRepository({
    required SupabaseBookRepository remoteRepo,
    required BookCacheStore cacheStore,
    required NetworkInfo networkInfo,
  })  : _remoteRepo = remoteRepo,
        _cacheStore = cacheStore,
        _networkInfo = networkInfo;

  final SupabaseBookRepository _remoteRepo;
  final BookCacheStore _cacheStore;
  final NetworkInfo _networkInfo;

  // ===========================================================================
  // CACHE-ASIDE methods (6)
  // ===========================================================================

  @override
  Future<Either<Failure, Book>> getBookById(String id) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getBook(id);
      if (cached != null) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getBookById(id);

    // 3. Write to cache on success
    result.fold((_) {}, (book) {
      _cacheStore.saveBook(book).catchError((_) {});
    });

    return result;
  }

  @override
  Future<Either<Failure, List<Chapter>>> getChapters(String bookId) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getChapters(bookId);
      if (cached.isNotEmpty) {
        // Fire-and-forget freshness check
        _checkChapterFreshness(bookId);
        return Right(cached);
      }
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getChapters(bookId);

    // 3. Write to cache on success
    result.fold((_) {}, (chapters) {
      _cacheStore.saveChapters(bookId, chapters).catchError((_) {});
    });

    return result;
  }

  @override
  Future<Either<Failure, Chapter>> getChapterById(String chapterId) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getChapterById(chapterId);
      if (cached != null) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getChapterById(chapterId);

    // 3. Write to cache on success
    result.fold((_) {}, (chapter) {
      _cacheStore
          .saveChapters(chapter.bookId, [chapter])
          .catchError((_) {});
    });

    return result;
  }

  @override
  Future<Either<Failure, ReadingProgress>> getReadingProgress({
    required String userId,
    required String bookId,
  }) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getReadingProgress(
        userId: userId,
        bookId: bookId,
      );
      if (cached != null) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getReadingProgress(
      userId: userId,
      bookId: bookId,
    );

    // 3. Write to cache on success
    result.fold((_) {}, (progress) {
      _cacheStore.saveReadingProgress(progress).catchError((_) {});
    });

    return result;
  }

  @override
  Future<Either<Failure, List<InlineActivity>>> getInlineActivities(
    String chapterId,
  ) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getInlineActivities(chapterId);
      if (cached.isNotEmpty) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getInlineActivities(chapterId);

    // 3. Write to cache on success
    result.fold((_) {}, (activities) {
      _cacheStore
          .saveInlineActivities(chapterId, activities)
          .catchError((_) {});
    });

    return result;
  }

  @override
  Future<Either<Failure, Map<String, bool>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  }) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getCompletedInlineActivityIds(
        userId: userId,
        chapterId: chapterId,
      );
      if (cached.isNotEmpty) {
        // Cache only returns IDs, not correctness — assume true for cached
        return Right({for (final id in cached) id: true});
      }
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      // Graceful degradation: return empty map instead of error
      return const Right({});
    }
    final result = await _remoteRepo.getCompletedInlineActivities(
      userId: userId,
      chapterId: chapterId,
    );

    return result;
  }

  // ===========================================================================
  // WRITE-THROUGH methods (4)
  // ===========================================================================

  @override
  Future<Either<Failure, ReadingProgress>> updateReadingProgress(
    ReadingProgress progress,
  ) async {
    final online = await _networkInfo.isConnected;

    if (online) {
      // Write to remote first
      final result = await _remoteRepo.updateReadingProgress(progress);
      // Cache the server response on success
      result.fold((_) {}, (updated) {
        _cacheStore.saveReadingProgress(updated).catchError((_) {});
      });
      return result;
    }

    // Offline: save to cache with dirty flag
    try {
      final updated = progress.copyWith(updatedAt: DateTime.now());
      await _cacheStore.saveReadingProgress(updated, isDirty: true);
      return Right(updated);
    } catch (e) {
      return Left(CacheFailure('Failed to save reading progress offline: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateCurrentChapter({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    final online = await _networkInfo.isConnected;

    if (online) {
      final result = await _remoteRepo.updateCurrentChapter(
        userId: userId,
        bookId: bookId,
        chapterId: chapterId,
      );
      // Update cache on success
      result.fold((_) {}, (_) async {
        try {
          final cached = await _cacheStore.getReadingProgress(
            userId: userId,
            bookId: bookId,
          );
          if (cached != null) {
            final updated = cached.copyWith(
              chapterId: chapterId,
              updatedAt: DateTime.now(),
            );
            await _cacheStore.saveReadingProgress(updated);
          }
        } catch (_) {}
      });
      return result;
    }

    // Offline: update cached progress
    try {
      final cached = await _cacheStore.getReadingProgress(
        userId: userId,
        bookId: bookId,
      );
      if (cached != null) {
        final updated = cached.copyWith(
          chapterId: chapterId,
          updatedAt: DateTime.now(),
        );
        await _cacheStore.saveReadingProgress(updated, isDirty: true);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to update current chapter offline: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
    List<String> wordsLearned = const [],
  }) async {
    final online = await _networkInfo.isConnected;

    if (online) {
      final result = await _remoteRepo.saveInlineActivityResult(
        userId: userId,
        activityId: activityId,
        isCorrect: isCorrect,
        xpEarned: xpEarned,
        wordsLearned: wordsLearned,
      );
      // Cache the result on success
      result.fold((_) {}, (_) async {
        try {
          final bookId = await _cacheStore.getBookIdForActivity(activityId);
          await _cacheStore.saveInlineActivityResult(
            activityId: activityId,
            bookId: bookId,
            userId: userId,
            isCorrect: isCorrect,
            xpEarned: xpEarned,
          );
        } catch (_) {}
      });
      return result;
    }

    // Offline: check if already completed, save with dirty flag
    try {
      final alreadyExists =
          await _cacheStore.hasInlineActivityResult(activityId);
      if (alreadyExists) {
        return const Right(false); // Already completed — no XP
      }

      final bookId = await _cacheStore.getBookIdForActivity(activityId);
      await _cacheStore.saveInlineActivityResult(
        activityId: activityId,
        bookId: bookId,
        userId: userId,
        isCorrect: isCorrect,
        xpEarned: xpEarned,
        isDirty: true,
      );
      // Optimistically return true (new completion)
      return const Right(true);
    } catch (e) {
      return Left(
        CacheFailure('Failed to save inline activity result offline: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, ReadingProgress>> markChapterComplete({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    final online = await _networkInfo.isConnected;

    if (online) {
      final result = await _remoteRepo.markChapterComplete(
        userId: userId,
        bookId: bookId,
        chapterId: chapterId,
      );
      // Cache the updated progress on success
      result.fold((_) {}, (progress) {
        _cacheStore.saveReadingProgress(progress).catchError((_) {});
      });
      return result;
    }

    // Offline: compute locally
    return _markChapterCompleteOffline(
      userId: userId,
      bookId: bookId,
      chapterId: chapterId,
    );
  }

  /// Offline implementation of [markChapterComplete].
  ///
  /// Reads current progress and chapter list from cache, calculates the new
  /// completion percentage, checks quiz existence, writes back with dirty flag,
  /// and queues pending actions for sync.
  Future<Either<Failure, ReadingProgress>> _markChapterCompleteOffline({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    try {
      // 1. Read reading progress from cache
      final progress = await _cacheStore.getReadingProgress(
        userId: userId,
        bookId: bookId,
      );
      if (progress == null) {
        return const Left(
          CacheFailure('No cached reading progress found for this book'),
        );
      }

      // 2. Read all chapters from cache to count total
      final chapters = await _cacheStore.getChapters(bookId);
      if (chapters.isEmpty) {
        return const Left(
          CacheFailure('No cached chapters found for this book'),
        );
      }

      // 3. Add chapter to completed list if not already there
      final completedChapters =
          List<String>.from(progress.completedChapterIds);
      if (!completedChapters.contains(chapterId)) {
        completedChapters.add(chapterId);
      }

      // 4. Calculate completion percentage (do NOT set is_completed — UseCase handles that)
      final totalChapters = chapters.length;
      final completedCount = completedChapters.length;
      final percentage = totalChapters > 0
          ? (completedCount / totalChapters) * 100
          : 0.0;

      // 5. Build updated progress
      final now = DateTime.now();
      final updatedProgress = progress.copyWith(
        completedChapterIds: completedChapters,
        completionPercentage: percentage,
        updatedAt: now,
      );

      // 6. Write to cache with dirty flag
      await _cacheStore.saveReadingProgress(updatedProgress, isDirty: true);

      // 7. Queue pending actions for sync
      await _cacheStore.queuePendingAction(
        actionType: 'award_xp',
        payload: {
          'user_id': userId,
          'book_id': bookId,
          'chapter_id': chapterId,
          'source': 'chapter_complete',
          'source_id': chapterId,
        },
        bookId: bookId,
      );
      await _cacheStore.queuePendingAction(
        actionType: 'log_daily_read',
        payload: {
          'user_id': userId,
          'chapter_id': chapterId,
        },
        bookId: bookId,
      );

      return Right(updatedProgress);
    } catch (e) {
      return Left(
        CacheFailure('Failed to mark chapter complete offline: $e'),
      );
    }
  }

  // ===========================================================================
  // PASS-THROUGH methods (11)
  // ===========================================================================

  @override
  Future<Either<Failure, List<Book>>> getBooks({
    String? level,
    String? genre,
    String? ageGroup,
    int page = 1,
    int pageSize = 20,
  }) {
    return _remoteRepo.getBooks(
      level: level,
      genre: genre,
      ageGroup: ageGroup,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Either<Failure, List<Book>>> getBooksByIds(List<String> ids) {
    return _remoteRepo.getBooksByIds(ids);
  }

  @override
  Future<Either<Failure, List<Book>>> searchBooks(String query) {
    return _remoteRepo.searchBooks(query);
  }

  @override
  Future<Either<Failure, List<Book>>> getContinueReading(String userId) {
    return _remoteRepo.getContinueReading(userId);
  }

  @override
  Future<Either<Failure, List<ReadingProgress>>> getUserReadingHistory(
    String userId,
  ) {
    return _remoteRepo.getUserReadingHistory(userId);
  }

  @override
  Future<Either<Failure, Set<String>>> getCompletedBookIds(String userId) {
    return _remoteRepo.getCompletedBookIds(userId);
  }

  @override
  Future<Either<Failure, bool>> hasReadToday(String userId) {
    return _remoteRepo.hasReadToday(userId);
  }

  @override
  Future<Either<Failure, int>> getCorrectAnswersTodayCount(String userId) {
    return _remoteRepo.getCorrectAnswersTodayCount(userId);
  }

  @override
  Future<Either<Failure, int>> getWordsReadTodayCount(String userId) {
    return _remoteRepo.getWordsReadTodayCount(userId);
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  /// Background freshness check for cached chapters.
  ///
  /// Compares server timestamps to local timestamps and re-downloads any
  /// chapters that have been updated on the server. This runs fire-and-forget
  /// so it never blocks the caller.
  Future<void> _checkChapterFreshness(String bookId) async {
    try {
      if (!await _networkInfo.isConnected) return;
      final remoteResult = await _remoteRepo.getChapters(bookId);
      remoteResult.fold((_) {}, (remoteChapters) async {
        final localTimestamps = await _cacheStore.getChapterTimestamps(bookId);
        for (final chapter in remoteChapters) {
          final localTs = localTimestamps[chapter.id];
          if (localTs == null ||
              chapter.updatedAt.toIso8601String() != localTs) {
            await _cacheStore.saveChapters(bookId, [chapter]);
          }
        }
      });
    } catch (e) {
      // Best-effort — log in debug mode, never throw.
      debugPrint('CachedBookRepository: chapter freshness check failed: $e');
    }
  }
}
