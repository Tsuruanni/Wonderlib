import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'book_cache_store.dart';

part 'file_cache_service.g.dart';

/// Downloads and caches image/audio files to the local filesystem.
///
/// Metadata (url → local_path mapping) is tracked in sqflite via
/// [BookCacheStore]. Files are stored under:
///   `<ApplicationDocumentsDirectory>/book_cache/<bookId>/<md5(url)>.<ext>`
///
/// On web, all caching is disabled and remote URLs are returned as-is.
class FileCacheService {
  FileCacheService(this._cacheStore);

  final BookCacheStore _cacheStore;

  Future<Directory> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'book_cache'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the local file path for [remoteUrl], downloading it if needed.
  ///
  /// [bookId] is used to organise files on disk and track size per book.
  /// [fileType] is a short label stored in the DB (e.g. `'image'`, `'audio'`).
  Future<String> getOrDownload(
    String remoteUrl,
    String bookId,
    String fileType,
  ) async {
    // File caching not available on web
    if (kIsWeb) return remoteUrl;

    // 1. Check DB cache
    final cached = await _cacheStore.getLocalFilePath(remoteUrl);
    if (cached != null) {
      final file = File(cached);
      if (file.existsSync()) {
        return cached;
      }
      // Stale record — file was deleted from disk; re-download below.
    }

    // 2. Download
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode != 200) {
      throw Exception(
        'FileCacheService: HTTP ${response.statusCode} for $remoteUrl',
      );
    }

    // 3. Build local path
    final ext = _extensionFromUrl(remoteUrl);
    final hash = md5.convert(remoteUrl.codeUnits).toString();
    final base = await _baseDir;
    final bookDir = Directory(p.join(base.path, bookId));
    if (!bookDir.existsSync()) {
      await bookDir.create(recursive: true);
    }
    final localPath = p.join(bookDir.path, '$hash$ext');

    // 4. Write to disk
    await File(localPath).writeAsBytes(response.bodyBytes);

    // 5. Record in DB
    await _cacheStore.saveFile(
      url: remoteUrl,
      bookId: bookId,
      localPath: localPath,
      fileType: fileType,
      fileSize: response.bodyBytes.length,
    );

    return localPath;
  }

  /// Returns the local path if cached and present on disk, otherwise returns
  /// the original [remoteUrl] unchanged.
  Future<String> resolveUrl(String remoteUrl) async {
    if (kIsWeb) return remoteUrl;
    final cached = await _cacheStore.getLocalFilePath(remoteUrl);
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }
    return remoteUrl;
  }

  /// Deletes the on-disk directory for [bookId].
  ///
  /// DB records are cascade-deleted by [BookCacheStore.deleteBook] via the
  /// `cached_files` FK; this method only removes the filesystem files.
  Future<void> deleteBookFiles(String bookId) async {
    if (kIsWeb) return;
    final base = await _baseDir;
    final bookDir = Directory(p.join(base.path, bookId));
    if (bookDir.existsSync()) {
      await bookDir.delete(recursive: true);
    }
  }

  // ------------------------------------------------------------------

  /// Extract a file extension from a URL, defaulting to an empty string.
  String _extensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final lastSegment = uri.pathSegments.lastOrNull ?? '';
      final dotIndex = lastSegment.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < lastSegment.length - 1) {
        // Keep extension short (at most 5 chars) to avoid query-string bleed.
        final raw = lastSegment.substring(dotIndex);
        return raw.length <= 6 ? raw : '';
      }
    } catch (_) {}
    return '';
  }
}

@Riverpod(keepAlive: true)
FileCacheService fileCacheService(FileCacheServiceRef ref) {
  final cacheStore = ref.watch(bookCacheStoreProvider);
  return FileCacheService(cacheStore);
}
