import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../../domain/repositories/content_block_repository.dart';
import '../supabase/supabase_content_block_repository.dart';

/// Cached wrapper around [SupabaseContentBlockRepository].
///
/// Implements two strategies depending on the method:
///
/// **Cache-aside** — Check local cache first, fall back to remote on miss,
/// then write the remote result to cache for next time.
///
/// **Cache-aside (derived)** — For [chapterUsesContentBlocks], read the
/// `use_content_blocks` flag from the cached chapter row if available,
/// fall back to remote otherwise.
class CachedContentBlockRepository implements ContentBlockRepository {
  CachedContentBlockRepository({
    required SupabaseContentBlockRepository remoteRepo,
    required BookCacheStore cacheStore,
    required NetworkInfo networkInfo,
  })  : _remoteRepo = remoteRepo,
        _cacheStore = cacheStore,
        _networkInfo = networkInfo;

  final SupabaseContentBlockRepository _remoteRepo;
  final BookCacheStore _cacheStore;
  final NetworkInfo _networkInfo;

  // ===========================================================================
  // CACHE-ASIDE methods (3)
  // ===========================================================================

  @override
  Future<Either<Failure, List<ContentBlock>>> getContentBlocks(
    String chapterId,
  ) async {
    // 1. Try cache
    try {
      final cached = await _cacheStore.getContentBlocks(chapterId);
      if (cached.isNotEmpty) return Right(cached);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    final result = await _remoteRepo.getContentBlocks(chapterId);

    // 3. Write to cache on success
    result.fold((_) {}, (blocks) {
      _cacheStore.saveContentBlocks(chapterId, blocks).catchError((_) {});
    });

    return result;
  }

  @override
  Future<Either<Failure, bool>> chapterUsesContentBlocks(
    String chapterId,
  ) async {
    // 1. Try to derive from cached chapter row (no extra DB call)
    try {
      final chapter = await _cacheStore.getChapterById(chapterId);
      if (chapter != null) return Right(chapter.useContentBlocks);
    } catch (_) {
      // Cache read failed — fall through to remote.
    }

    // 2. Try remote
    if (!await _networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    return _remoteRepo.chapterUsesContentBlocks(chapterId);
  }
}
