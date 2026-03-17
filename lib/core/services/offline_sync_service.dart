import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:owlio_shared/owlio_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/activity/activity_result_model.dart';
import '../../data/models/book/reading_progress_model.dart';
import '../../data/models/book_quiz/book_quiz_result_model.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/book_quiz_repository.dart';
import '../../domain/repositories/book_repository.dart';
import '../../presentation/providers/repository_providers.dart';
import '../network/network_info.dart';
import 'book_cache_store.dart';
import 'edge_function_service.dart';

part 'offline_sync_service.g.dart';

/// Syncs dirty (locally-modified) records back to the server when
/// connectivity is restored.
///
/// Listens to [NetworkInfo.onConnectivityChanged] and triggers a full
/// sync whenever the device comes back online.
class OfflineSyncService {
  OfflineSyncService({
    required this.cacheStore,
    required this.bookRepo,
    required this.activityRepo,
    required this.quizRepo,
    required this.edgeFunctionService,
    required this.networkInfo,
  });

  final BookCacheStore cacheStore;
  final BookRepository bookRepo;
  final ActivityRepository activityRepo;
  final BookQuizRepository quizRepo;
  final EdgeFunctionService edgeFunctionService;
  final NetworkInfo networkInfo;

  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySub;

  /// Begin listening for connectivity changes. When the device comes
  /// back online, [syncAll] is called automatically.
  void startListening() {
    _connectivitySub?.cancel();
    _connectivitySub = networkInfo.onConnectivityChanged.listen((connected) {
      if (connected) {
        syncAll();
      }
    });
  }

  /// Stop listening for connectivity changes and cancel any in-flight work.
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Run the full sync pipeline. Silently returns if a sync is already in
  /// progress or the device is offline.
  Future<void> syncAll() async {
    if (_isSyncing) return;

    final connected = await networkInfo.isConnected;
    if (!connected) return;

    _isSyncing = true;
    try {
      debugPrint('[OfflineSyncService] syncAll started');

      await _syncReadingProgress();
      await _syncInlineActivityResults();
      await _syncActivityResults();
      await _syncQuizResults();
      await _syncPendingActions();
      await _refreshReadingProgressFromServer();

      debugPrint('[OfflineSyncService] syncAll completed');
    } catch (e, st) {
      debugPrint('[OfflineSyncService] syncAll unexpected error: $e\n$st');
    } finally {
      _isSyncing = false;
    }
  }

  // ================================================================
  // 1. READING PROGRESS
  // ================================================================

  /// Find dirty cached_reading_progress records and upsert them to the
  /// remote server via [bookRepo.updateReadingProgress].
  Future<void> _syncReadingProgress() async {
    try {
      final dirtyRows = await cacheStore.getDirtyReadingProgress();
      if (dirtyRows.isEmpty) return;

      debugPrint(
        '[OfflineSyncService] syncing ${dirtyRows.length} dirty reading progress records',
      );

      for (final row in dirtyRows) {
        try {
          final json = row['progress_json'] as Map<String, dynamic>;
          final progress = ReadingProgressModel.fromJson(json).toEntity();

          final result = await bookRepo.updateReadingProgress(progress);
          result.fold(
            (failure) => debugPrint(
              '[OfflineSyncService] failed to sync reading progress '
              '${row['id']}: $failure',
            ),
            (_) => cacheStore.clearDirtyFlag(
              'cached_reading_progress',
              'id',
              row['id'] as String,
            ),
          );
        } catch (e) {
          debugPrint(
            '[OfflineSyncService] error syncing reading progress '
            '${row['id']}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] _syncReadingProgress error: $e');
    }
  }

  // ================================================================
  // 2. INLINE ACTIVITY RESULTS
  // ================================================================

  /// Find dirty cached_inline_activity_results and forward them to the
  /// remote server via [bookRepo.saveInlineActivityResult].
  Future<void> _syncInlineActivityResults() async {
    try {
      final dirtyRows = await cacheStore.getDirtyInlineActivityResults();
      if (dirtyRows.isEmpty) return;

      debugPrint(
        '[OfflineSyncService] syncing ${dirtyRows.length} dirty inline activity results',
      );

      for (final row in dirtyRows) {
        try {
          final activityId = row['inline_activity_id'] as String;
          final userId = row['user_id'] as String;
          final isCorrect = row['is_correct'] as bool;
          final xpEarned = row['xp_earned'] as int;

          final result = await bookRepo.saveInlineActivityResult(
            userId: userId,
            activityId: activityId,
            isCorrect: isCorrect,
            xpEarned: xpEarned,
          );
          result.fold(
            (failure) => debugPrint(
              '[OfflineSyncService] failed to sync inline activity result '
              '$activityId: $failure',
            ),
            (_) => cacheStore.clearDirtyFlag(
              'cached_inline_activity_results',
              'inline_activity_id',
              activityId,
            ),
          );
        } catch (e) {
          debugPrint(
            '[OfflineSyncService] error syncing inline activity result: $e',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[OfflineSyncService] _syncInlineActivityResults error: $e',
      );
    }
  }

  // ================================================================
  // 3. LEGACY ACTIVITY RESULTS
  // ================================================================

  /// Find dirty cached_activity_results, deserialize the result_json,
  /// and submit to the remote server via [activityRepo.submitActivityResult].
  Future<void> _syncActivityResults() async {
    try {
      final dirtyRows = await cacheStore.getDirtyActivityResults();
      if (dirtyRows.isEmpty) return;

      debugPrint(
        '[OfflineSyncService] syncing ${dirtyRows.length} dirty activity results',
      );

      for (final row in dirtyRows) {
        try {
          final id = row['id'] as String;
          final resultJson = row['result_json'] as Map<String, dynamic>;
          final activityResult =
              ActivityResultModel.fromJson(resultJson).toEntity();

          final result = await activityRepo.submitActivityResult(activityResult);
          result.fold(
            (failure) => debugPrint(
              '[OfflineSyncService] failed to sync activity result $id: $failure',
            ),
            (_) => cacheStore.clearDirtyFlag(
              'cached_activity_results',
              'id',
              id,
            ),
          );
        } catch (e) {
          debugPrint(
            '[OfflineSyncService] error syncing activity result: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] _syncActivityResults error: $e');
    }
  }

  // ================================================================
  // 4. QUIZ RESULTS
  // ================================================================

  /// Find dirty cached_book_quiz_results, deserialize the result_json,
  /// and submit to the remote server via [quizRepo.submitQuizResult].
  Future<void> _syncQuizResults() async {
    try {
      final dirtyRows = await cacheStore.getDirtyQuizResults();
      if (dirtyRows.isEmpty) return;

      debugPrint(
        '[OfflineSyncService] syncing ${dirtyRows.length} dirty quiz results',
      );

      for (final row in dirtyRows) {
        try {
          final id = row['id'] as String;
          final resultJson = row['result_json'] as Map<String, dynamic>;
          final quizResult =
              BookQuizResultModel.fromJson(resultJson).toEntity();

          final result = await quizRepo.submitQuizResult(quizResult);
          result.fold(
            (failure) => debugPrint(
              '[OfflineSyncService] failed to sync quiz result $id: $failure',
            ),
            (_) => cacheStore.clearDirtyFlag(
              'cached_book_quiz_results',
              'id',
              id,
            ),
          );
        } catch (e) {
          debugPrint(
            '[OfflineSyncService] error syncing quiz result: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] _syncQuizResults error: $e');
    }
  }

  // ================================================================
  // 5. PENDING ACTIONS
  // ================================================================

  /// Process offline_pending_actions in FIFO order.
  ///
  /// Supported action types:
  /// - `award_xp`: calls [EdgeFunctionService.awardXP]
  /// - `log_daily_read`: inserts into [DbTables.dailyChapterReads]
  /// - `check_assignment`: skipped (handled by reading progress sync)
  Future<void> _syncPendingActions() async {
    try {
      final actions = await cacheStore.getPendingActions();
      if (actions.isEmpty) return;

      debugPrint(
        '[OfflineSyncService] processing ${actions.length} pending actions',
      );

      for (final action in actions) {
        try {
          final id = action['id'] as int;
          final actionType = action['action_type'] as String;
          final payload = action['payload'] as Map<String, dynamic>;

          switch (actionType) {
            case 'award_xp':
              await _handleAwardXp(payload);
              await cacheStore.deletePendingAction(id);

            case 'log_daily_read':
              await _handleLogDailyRead(payload);
              await cacheStore.deletePendingAction(id);

            case 'check_assignment':
              // Handled implicitly by reading progress sync — just delete.
              await cacheStore.deletePendingAction(id);

            default:
              debugPrint(
                '[OfflineSyncService] unknown action type: $actionType, '
                'deleting action $id',
              );
              await cacheStore.deletePendingAction(id);
          }
        } catch (e) {
          debugPrint(
            '[OfflineSyncService] error processing pending action: $e',
          );
          // Continue to next action — don't let one failure block the rest.
        }
      }
    } catch (e) {
      debugPrint('[OfflineSyncService] _syncPendingActions error: $e');
    }
  }

  /// Call the award-xp edge function with the queued payload.
  Future<void> _handleAwardXp(Map<String, dynamic> payload) async {
    await edgeFunctionService.awardXP(
      userId: payload['userId'] as String,
      amount: payload['amount'] as int,
      source: payload['source'] as String,
      sourceId: payload['sourceId'] as String?,
      description: payload['description'] as String?,
    );
  }

  /// Insert a daily chapter read log entry directly into Supabase.
  Future<void> _handleLogDailyRead(Map<String, dynamic> payload) async {
    final supabase = Supabase.instance.client;
    await supabase.from(DbTables.dailyChapterReads).upsert(
      {
        'user_id': payload['user_id'] as String,
        'chapter_id': payload['chapter_id'] as String,
        'read_date': payload['read_date'] as String,
      },
      onConflict: 'user_id,chapter_id,read_date',
    );
  }

  // ================================================================
  // 6. REFRESH FROM SERVER
  // ================================================================

  /// After syncing dirty records, re-fetch reading progress for any books
  /// that had dirty progress. The server is authoritative, so we overwrite
  /// the local cache with the server's version.
  Future<void> _refreshReadingProgressFromServer() async {
    try {
      final dirtyRows = await cacheStore.getDirtyReadingProgress();
      // Collect unique (userId, bookId) pairs that still have dirty records.
      // In the happy path all dirty flags were already cleared by
      // _syncReadingProgress, but some may have failed.
      final bookUserPairs = <String>{};
      for (final row in dirtyRows) {
        bookUserPairs.add('${row['user_id']}|${row['book_id']}');
      }

      // Also refresh any books that were successfully synced (dirty flag
      // cleared) by re-checking all cached progress. We only refresh books
      // whose progress was recently dirty — tracked by collecting bookIds
      // before _syncReadingProgress clears flags. Since we run AFTER the
      // sync step, we need a different approach: refresh ALL cached books'
      // progress that the current user has. This keeps the implementation
      // simple and correct.
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final cachedBooks = await cacheStore.getAllCachedBooks();
      if (cachedBooks.isEmpty) return;

      debugPrint(
        '[OfflineSyncService] refreshing reading progress for '
        '${cachedBooks.length} cached books',
      );

      for (final entry in cachedBooks) {
        try {
          final book = entry['book'] as dynamic;
          final bookId = book.id as String;

          final result = await bookRepo.getReadingProgress(
            userId: currentUser.id,
            bookId: bookId,
          );
          result.fold(
            (failure) {
              // Not all books have progress — this is fine.
            },
            (progress) async {
              await cacheStore.saveReadingProgress(progress, isDirty: false);
            },
          );
        } catch (e) {
          debugPrint(
            '[OfflineSyncService] error refreshing progress: $e',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[OfflineSyncService] _refreshReadingProgressFromServer error: $e',
      );
    }
  }
}

@Riverpod(keepAlive: true)
OfflineSyncService offlineSyncService(OfflineSyncServiceRef ref) {
  final service = OfflineSyncService(
    cacheStore: ref.watch(bookCacheStoreProvider),
    bookRepo: ref.watch(bookRepositoryProvider),
    activityRepo: ref.watch(activityRepositoryProvider),
    quizRepo: ref.watch(bookQuizRepositoryProvider),
    edgeFunctionService: ref.watch(edgeFunctionServiceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
  service.startListening();
  ref.onDispose(() => service.dispose());
  return service;
}
