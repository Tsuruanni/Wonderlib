import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/network_info.dart';

part 'sync_service.g.dart';

/// Sync item types for offline-first operations
enum SyncType {
  readingProgress,
  activityResult,
  vocabularyProgress,
}

/// Represents a pending sync operation
class SyncItem {
  final String id;
  final SyncType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  SyncItem({
    required this.id,
    required this.type,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  SyncItem copyWith({int? retryCount}) {
    return SyncItem(
      id: id,
      type: type,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    return SyncItem(
      id: json['id'] as String,
      type: SyncType.values.byName(json['type'] as String),
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}

/// Service responsible for syncing local changes to the server
abstract class SyncService {
  /// Queue an item for sync
  Future<void> queueSync(SyncItem item);

  /// Process all pending sync items
  Future<void> syncAll();

  /// Get count of pending items
  Future<int> get pendingCount;

  /// Stream of sync status updates
  Stream<SyncStatus> get statusStream;
}

class SyncStatus {
  final bool isSyncing;
  final int pendingCount;
  final int syncedCount;
  final String? lastError;

  const SyncStatus({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.lastError,
  });

  SyncStatus copyWith({
    bool? isSyncing,
    int? pendingCount,
    int? syncedCount,
    String? lastError,
  }) {
    return SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      syncedCount: syncedCount ?? this.syncedCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Implementation will be added when local database is set up
class SyncServiceImpl implements SyncService {
  final NetworkInfo _networkInfo;
  final _statusController = StreamController<SyncStatus>.broadcast();
  final List<SyncItem> _queue = [];

  SyncServiceImpl({required NetworkInfo networkInfo})
      : _networkInfo = networkInfo {
    // Listen for connectivity changes to trigger sync
    _networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        syncAll();
      }
    });
  }

  @override
  Future<void> queueSync(SyncItem item) async {
    _queue.add(item);
    _statusController.add(SyncStatus(pendingCount: _queue.length));

    // Try to sync immediately if online
    if (await _networkInfo.isConnected) {
      syncAll();
    }
  }

  @override
  Future<void> syncAll() async {
    if (_queue.isEmpty) return;
    if (!await _networkInfo.isConnected) return;

    _statusController.add(SyncStatus(
      isSyncing: true,
      pendingCount: _queue.length,
    ));

    var syncedCount = 0;
    final failedItems = <SyncItem>[];

    for (final item in List.from(_queue)) {
      try {
        await _syncItem(item);
        _queue.remove(item);
        syncedCount++;
        _statusController.add(SyncStatus(
          isSyncing: true,
          pendingCount: _queue.length,
          syncedCount: syncedCount,
        ));
      } catch (e) {
        // Keep for retry, increment retry count
        if (item.retryCount < 3) {
          failedItems.add(item.copyWith(retryCount: item.retryCount + 1));
        }
        _queue.remove(item);
      }
    }

    _queue.addAll(failedItems);
    _statusController.add(SyncStatus(
      isSyncing: false,
      pendingCount: _queue.length,
      syncedCount: syncedCount,
    ));
  }

  Future<void> _syncItem(SyncItem item) async {
    // TODO: Implement actual sync logic with Supabase
    // This will be implemented when data sources are set up
    switch (item.type) {
      case SyncType.readingProgress:
        // await _supabase.from('reading_progress').upsert(item.data);
        break;
      case SyncType.activityResult:
        // await _supabase.from('activity_results').insert(item.data);
        break;
      case SyncType.vocabularyProgress:
        // await _supabase.from('vocabulary_progress').upsert(item.data);
        break;
    }
  }

  @override
  Future<int> get pendingCount async => _queue.length;

  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;
}

@riverpod
SyncService syncService(SyncServiceRef ref) {
  final networkInfo = ref.watch(networkInfoProvider);
  return SyncServiceImpl(networkInfo: networkInfo);
}
