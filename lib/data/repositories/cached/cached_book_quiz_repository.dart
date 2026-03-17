import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/book_quiz.dart';
import '../../../domain/repositories/book_quiz_repository.dart';
import '../supabase/supabase_book_quiz_repository.dart';

/// Cached wrapper around [SupabaseBookQuizRepository].
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
/// **Pass-through** — Always delegate to remote. Used for teacher-facing
/// aggregate queries that are not worth caching.
class CachedBookQuizRepository implements BookQuizRepository {
  CachedBookQuizRepository({
    required SupabaseBookQuizRepository remoteRepo,
    required BookCacheStore cacheStore,
    required NetworkInfo networkInfo,
  })  : _remoteRepo = remoteRepo,
        _cacheStore = cacheStore,
        _networkInfo = networkInfo;

  final SupabaseBookQuizRepository _remoteRepo;
  final BookCacheStore _cacheStore;
  final NetworkInfo _networkInfo;

  // ===========================================================================
  // CACHE-ASIDE methods (4)
  // ===========================================================================

  @override
  Future<Either<Failure, BookQuiz?>> getQuizForBook(String bookId) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getQuizForBook(bookId);
      if (cached != null) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getQuizForBook(bookId);

    // 3. Write to cache on success (only if quiz exists)
    result.fold((_) {}, (quiz) {
      if (quiz != null) {
        _cacheStore.saveQuiz(bookId, quiz).catchError((_) {});
      }
    });

    return result;
  }

  @override
  Future<Either<Failure, bool>> bookHasQuiz(String bookId) async {
    // 1. Try cache — derived from whether a quiz row exists locally
    try {
      final hasQuiz = await _cacheStore.bookHasQuiz(bookId);
      if (hasQuiz) return const Right(true);
      // If cache says false, it could be a cache miss rather than truly no quiz.
      // Fall through to remote to confirm.
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    return _remoteRepo.bookHasQuiz(bookId);
  }

  @override
  Future<Either<Failure, BookQuizResult?>> getBestResult({
    required String userId,
    required String bookId,
  }) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getBestQuizResult(
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
    final result = await _remoteRepo.getBestResult(
      userId: userId,
      bookId: bookId,
    );

    // 3. Write to cache on success
    result.fold((_) {}, (quizResult) {
      if (quizResult != null) {
        _cacheStore
            .saveQuizResult(quizResult, bookId)
            .catchError((_) {});
      }
    });

    return result;
  }

  @override
  Future<Either<Failure, List<BookQuizResult>>> getUserQuizResults({
    required String userId,
    required String bookId,
  }) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getUserQuizResults(
        userId: userId,
        bookId: bookId,
      );
      if (cached.isNotEmpty) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getUserQuizResults(
      userId: userId,
      bookId: bookId,
    );

    // 3. Write each result to cache on success
    result.fold((_) {}, (results) {
      for (final quizResult in results) {
        _cacheStore
            .saveQuizResult(quizResult, bookId)
            .catchError((_) {});
      }
    });

    return result;
  }

  // ===========================================================================
  // WRITE-THROUGH methods (1)
  // ===========================================================================

  @override
  Future<Either<Failure, BookQuizResult>> submitQuizResult(
    BookQuizResult result,
  ) async {
    final online = await _networkInfo.isConnected;

    if (online) {
      // Write to remote first
      final remoteResult = await _remoteRepo.submitQuizResult(result);
      // Cache the server response on success
      remoteResult.fold((_) {}, (saved) {
        _cacheStore
            .saveQuizResult(saved, saved.bookId)
            .catchError((_) {});
      });
      return remoteResult;
    }

    // Offline: save to cache with dirty flag
    try {
      await _cacheStore.saveQuizResult(result, result.bookId, isDirty: true);
      return Right(result);
    } catch (e) {
      return Left(CacheFailure('Failed to save quiz result offline: $e'));
    }
  }

  // ===========================================================================
  // PASS-THROUGH methods (1)
  // ===========================================================================

  @override
  Future<Either<Failure, List<StudentQuizProgress>>> getStudentQuizResults(
    String studentId,
  ) {
    return _remoteRepo.getStudentQuizResults(studentId);
  }
}
