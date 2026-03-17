import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../models/activity/activity_result_model.dart';
import '../supabase/supabase_activity_repository.dart';

/// Cached wrapper around [SupabaseActivityRepository].
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
/// **Pass-through** — Always delegate to remote. Used for user-scoped
/// aggregate queries that are not worth caching.
class CachedActivityRepository implements ActivityRepository {
  CachedActivityRepository({
    required SupabaseActivityRepository remoteRepo,
    required BookCacheStore cacheStore,
    required NetworkInfo networkInfo,
  })  : _remoteRepo = remoteRepo,
        _cacheStore = cacheStore,
        _networkInfo = networkInfo;

  final SupabaseActivityRepository _remoteRepo;
  final BookCacheStore _cacheStore;
  final NetworkInfo _networkInfo;

  // ===========================================================================
  // CACHE-ASIDE methods (2)
  // ===========================================================================

  @override
  Future<Either<Failure, List<Activity>>> getActivitiesByChapter(
    String chapterId,
  ) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getActivities(chapterId);
      if (cached.isNotEmpty) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getActivitiesByChapter(chapterId);

    // 3. Write to cache on success
    result.fold((_) {}, (activities) {
      _cacheStore.saveActivities(chapterId, activities).catchError((_) {});
    });

    return result;
  }

  @override
  Future<Either<Failure, Activity>> getActivityById(String id) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getActivityById(id);
      if (cached != null) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    return _remoteRepo.getActivityById(id);

    // Note: We do not save a single activity independently because
    // saveActivities() replaces ALL activities for a chapter atomically.
    // Single-activity caching would leave the cache in a partial state.
  }

  // ===========================================================================
  // WRITE-THROUGH methods (1)
  // ===========================================================================

  @override
  Future<Either<Failure, ActivityResult>> submitActivityResult(
    ActivityResult result,
  ) async {
    final online = await _networkInfo.isConnected;

    if (online) {
      // Write to remote first
      final remoteResult = await _remoteRepo.submitActivityResult(result);
      // Cache the server response on success
      remoteResult.fold((_) {}, (saved) {
        final model = ActivityResultModel.fromEntity(saved);
        // bookId is not available on ActivityResult — use empty string.
        // cached_activity_results has no FK constraint on book_id.
        _cacheStore
            .saveActivityResult(
              model.toJson(),
              activityId: saved.activityId,
              bookId: '',
              userId: saved.userId,
            )
            .catchError((_) {});
      });
      return remoteResult;
    }

    // Offline: save to cache with dirty flag
    try {
      final model = ActivityResultModel.fromEntity(result);
      await _cacheStore.saveActivityResult(
        model.toJson(),
        activityId: result.activityId,
        bookId: '',
        userId: result.userId,
        isDirty: true,
      );
      return Right(result);
    } catch (e) {
      return Left(CacheFailure('Failed to save activity result offline: $e'));
    }
  }

  // ===========================================================================
  // PASS-THROUGH methods (3)
  // ===========================================================================

  @override
  Future<Either<Failure, List<ActivityResult>>> getUserActivityResults({
    required String userId,
    String? activityId,
  }) {
    return _remoteRepo.getUserActivityResults(
      userId: userId,
      activityId: activityId,
    );
  }

  @override
  Future<Either<Failure, ActivityResult?>> getBestResult({
    required String userId,
    required String activityId,
  }) {
    return _remoteRepo.getBestResult(userId: userId, activityId: activityId);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getActivityStats(
    String userId,
  ) {
    return _remoteRepo.getActivityStats(userId);
  }
}
