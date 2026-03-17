import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/activity/activity_model.dart';
import '../../data/models/activity/inline_activity_model.dart';
import '../../data/models/book/book_model.dart';
import '../../data/models/book/chapter_model.dart';
import '../../data/models/book/reading_progress_model.dart';
import '../../data/models/book_quiz/book_quiz_model.dart';
import '../../data/models/book_quiz/book_quiz_result_model.dart';
import '../../data/models/content/content_block_model.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_quiz.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/content/content_block.dart';
import '../../domain/entities/reading_progress.dart';
import 'book_cache_database.dart';

part 'book_cache_store.g.dart';

/// Data access layer for all book cache database tables.
///
/// All model data is stored as JSON blobs in TEXT columns. Serialization goes
/// through the existing Model classes: `Model.fromEntity()` -> `toJson()` ->
/// `jsonEncode` for writes, and `jsonDecode` -> `Model.fromJson()` ->
/// `toEntity()` for reads.
///
/// Write methods accept domain entities and convert to models internally.
/// Read methods return domain entities (not models).
class BookCacheStore {
  BookCacheStore(this._cacheDb);

  final BookCacheDatabase _cacheDb;

  Future<Database> get _db => _cacheDb.database;

  // ================================================================
  // BOOKS
  // ================================================================

  /// Retrieve a cached book by ID. Returns `null` if not cached.
  Future<Book?> getBook(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_books',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['book_json'] as String) as Map<String, dynamic>;
    return BookModel.fromJson(json).toEntity();
  }

  /// Save a book to cache. Optionally set an initial download status.
  Future<void> saveBook(Book book, {String? downloadStatus}) async {
    final db = await _db;
    final model = BookModel.fromEntity(book);
    await db.insert(
      'cached_books',
      {
        'book_id': book.id,
        'book_json': jsonEncode(model.toJson()),
        'updated_at': book.updatedAt.toIso8601String(),
        'cached_at': DateTime.now().toIso8601String(),
        'download_status': downloadStatus ?? 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the download status for a book. Returns `null` if book is not cached.
  Future<String?> getDownloadStatus(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_books',
      columns: ['download_status'],
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (rows.isEmpty) return null;
    return rows.first['download_status'] as String?;
  }

  /// Update the download status for an already-cached book.
  Future<void> setDownloadStatus(String bookId, String status) async {
    final db = await _db;
    await db.update(
      'cached_books',
      {'download_status': status},
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  /// Delete a book and all cascade-linked data (chapters, content blocks,
  /// activities, quizzes, vocabulary, files, pending actions).
  ///
  /// Progress tables (reading_progress, inline_activity_results,
  /// activity_results) are intentionally NOT cascade-deleted because they
  /// have no FK to cached_books.
  Future<void> deleteBook(String bookId) async {
    final db = await _db;
    await db.delete(
      'cached_books',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  /// Return all cached books with their metadata.
  ///
  /// Each map contains: `book` (Book entity), `download_status`, `cached_at`.
  Future<List<Map<String, dynamic>>> getAllCachedBooks() async {
    final db = await _db;
    final rows = await db.query('cached_books');
    return rows.map((row) {
      final json = jsonDecode(row['book_json'] as String) as Map<String, dynamic>;
      return {
        'book': BookModel.fromJson(json).toEntity(),
        'download_status': row['download_status'] as String,
        'cached_at': row['cached_at'] as String,
      };
    }).toList();
  }

  // ================================================================
  // CHAPTERS
  // ================================================================

  /// Get all chapters for a book, ordered by order_index.
  Future<List<Chapter>> getChapters(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'order_index ASC',
    );
    return rows.map((row) {
      final json = jsonDecode(row['chapter_json'] as String) as Map<String, dynamic>;
      return ChapterModel.fromJson(json).toEntity();
    }).toList();
  }

  /// Get a single chapter by its ID.
  Future<Chapter?> getChapterById(String chapterId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_chapters',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
    );
    if (rows.isEmpty) return null;
    final json = jsonDecode(rows.first['chapter_json'] as String) as Map<String, dynamic>;
    return ChapterModel.fromJson(json).toEntity();
  }

  /// Save chapters for a book using a batch insert/replace.
  Future<void> saveChapters(String bookId, List<Chapter> chapters) async {
    final db = await _db;
    final batch = db.batch();
    for (final chapter in chapters) {
      final model = ChapterModel.fromEntity(chapter);
      batch.insert(
        'cached_chapters',
        {
          'chapter_id': chapter.id,
          'book_id': bookId,
          'chapter_json': jsonEncode(model.toJson()),
          'updated_at': chapter.updatedAt.toIso8601String(),
          'order_index': chapter.orderIndex,
          'use_content_blocks': chapter.useContentBlocks ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get a map of chapterId -> updatedAt for all cached chapters of a book.
  ///
  /// Useful for incremental sync — compare server timestamps to decide
  /// which chapters need re-downloading.
  Future<Map<String, String>> getChapterTimestamps(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_chapters',
      columns: ['chapter_id', 'updated_at'],
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return {
      for (final row in rows)
        row['chapter_id'] as String: row['updated_at'] as String,
    };
  }

  // ================================================================
  // CONTENT BLOCKS
  // ================================================================

  /// Get all content blocks for a chapter, ordered by order_index.
  Future<List<ContentBlock>> getContentBlocks(String chapterId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_content_blocks',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'order_index ASC',
    );
    return rows.map((row) {
      final json =
          jsonDecode(row['content_block_json'] as String) as Map<String, dynamic>;
      return ContentBlockModel.fromJson(json).toEntity();
    }).toList();
  }

  /// Get a single content block by ID.
  Future<ContentBlock?> getContentBlockById(String blockId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_content_blocks',
      where: 'id = ?',
      whereArgs: [blockId],
    );
    if (rows.isEmpty) return null;
    final json =
        jsonDecode(rows.first['content_block_json'] as String) as Map<String, dynamic>;
    return ContentBlockModel.fromJson(json).toEntity();
  }

  /// Replace all content blocks for a chapter (delete old + batch insert).
  Future<void> saveContentBlocks(
    String chapterId,
    List<ContentBlock> blocks,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'cached_content_blocks',
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
      );
      final batch = txn.batch();
      for (final block in blocks) {
        final model = ContentBlockModel.fromEntity(block);
        batch.insert('cached_content_blocks', {
          'id': block.id,
          'chapter_id': chapterId,
          'content_block_json': jsonEncode(model.toJson()),
          'order_index': block.orderIndex,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // ================================================================
  // INLINE ACTIVITIES
  // ================================================================

  /// Get all inline activities for a chapter, ordered by after_paragraph_index.
  Future<List<InlineActivity>> getInlineActivities(String chapterId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_inline_activities',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'after_paragraph_index ASC',
    );
    return rows.map((row) {
      final json =
          jsonDecode(row['activity_json'] as String) as Map<String, dynamic>;
      return InlineActivityModel.fromJson(json).toEntity();
    }).toList();
  }

  /// Replace all inline activities for a chapter (delete old + batch insert).
  Future<void> saveInlineActivities(
    String chapterId,
    List<InlineActivity> activities,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'cached_inline_activities',
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
      );
      final batch = txn.batch();
      for (final activity in activities) {
        final model = InlineActivityModel.fromEntity(activity);
        batch.insert('cached_inline_activities', {
          'id': activity.id,
          'chapter_id': chapterId,
          'activity_json': jsonEncode(model.toJson()),
          'after_paragraph_index': activity.afterParagraphIndex,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // ================================================================
  // LEGACY ACTIVITIES
  // ================================================================

  /// Get all legacy activities for a chapter, ordered by order_index.
  Future<List<Activity>> getActivities(String chapterId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_activities',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'order_index ASC',
    );
    return rows.map((row) {
      final json =
          jsonDecode(row['activity_json'] as String) as Map<String, dynamic>;
      return ActivityModel.fromJson(json).toEntity();
    }).toList();
  }

  /// Get a single legacy activity by ID.
  Future<Activity?> getActivityById(String activityId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_activities',
      where: 'id = ?',
      whereArgs: [activityId],
    );
    if (rows.isEmpty) return null;
    final json =
        jsonDecode(rows.first['activity_json'] as String) as Map<String, dynamic>;
    return ActivityModel.fromJson(json).toEntity();
  }

  /// Replace all legacy activities for a chapter (delete old + batch insert).
  Future<void> saveActivities(
    String chapterId,
    List<Activity> activities,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'cached_activities',
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
      );
      final batch = txn.batch();
      for (final activity in activities) {
        final model = ActivityModel.fromEntity(activity);
        batch.insert('cached_activities', {
          'id': activity.id,
          'chapter_id': chapterId,
          'activity_json': jsonEncode(model.toJson()),
          'order_index': activity.orderIndex,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // ================================================================
  // BOOK QUIZZES
  // ================================================================

  /// Get the quiz for a book. Returns `null` if no quiz is cached.
  Future<BookQuiz?> getQuizForBook(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_book_quizzes',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (rows.isEmpty) return null;
    final json =
        jsonDecode(rows.first['quiz_json'] as String) as Map<String, dynamic>;
    return BookQuizModel.fromJson(json).toEntity();
  }

  /// Check whether a quiz exists in cache for a book.
  Future<bool> bookHasQuiz(String bookId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM cached_book_quizzes WHERE book_id = ?',
      [bookId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Save a book quiz to cache.
  ///
  /// BookQuizModel.toJson() does not include questions, so we build the
  /// JSON blob manually to include `book_quiz_questions` (the key that
  /// `fromJson` expects).
  Future<void> saveQuiz(String bookId, BookQuiz quiz) async {
    final db = await _db;
    final model = BookQuizModel.fromEntity(quiz);
    // Build a complete JSON blob that includes questions under the
    // key BookQuizModel.fromJson expects: 'book_quiz_questions'.
    final quizJson = model.toJson();
    quizJson['book_quiz_questions'] =
        model.questions.map((q) => q.toJson()).toList();

    await db.insert(
      'cached_book_quizzes',
      {
        'quiz_id': quiz.id,
        'book_id': bookId,
        'quiz_json': jsonEncode(quizJson),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ================================================================
  // BOOK QUIZ RESULTS
  // ================================================================

  /// Save a quiz result to cache.
  Future<void> saveQuizResult(
    BookQuizResult result,
    String bookId, {
    bool isDirty = false,
  }) async {
    final db = await _db;
    final model = BookQuizResultModel.fromEntity(result);
    await db.insert(
      'cached_book_quiz_results',
      {
        'id': result.id,
        'quiz_id': result.quizId,
        'book_id': bookId,
        'user_id': result.userId,
        'result_json': jsonEncode(model.toJson()),
        'is_dirty': isDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the best quiz result (highest percentage) for a user + book.
  ///
  /// Fetches all results and sorts in Dart rather than using json_extract.
  Future<BookQuizResult?> getBestQuizResult({
    required String userId,
    required String bookId,
  }) async {
    final results = await getUserQuizResults(userId: userId, bookId: bookId);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.percentage.compareTo(a.percentage));
    return results.first;
  }

  /// Get all quiz results for a user + book, ordered by attempt number.
  Future<List<BookQuizResult>> getUserQuizResults({
    required String userId,
    required String bookId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'cached_book_quiz_results',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
    return rows.map((row) {
      final json =
          jsonDecode(row['result_json'] as String) as Map<String, dynamic>;
      return BookQuizResultModel.fromJson(json).toEntity();
    }).toList();
  }

  /// Get all quiz results that haven't been synced to the server yet.
  Future<List<Map<String, dynamic>>> getDirtyQuizResults() async {
    final db = await _db;
    final rows = await db.query(
      'cached_book_quiz_results',
      where: 'is_dirty = 1',
    );
    return rows.map((row) {
      return {
        'id': row['id'] as String,
        'quiz_id': row['quiz_id'] as String,
        'book_id': row['book_id'] as String,
        'user_id': row['user_id'] as String,
        'result_json': jsonDecode(row['result_json'] as String),
      };
    }).toList();
  }

  // ================================================================
  // READING PROGRESS
  // ================================================================

  /// Get the reading progress for a user + book.
  Future<ReadingProgress?> getReadingProgress({
    required String userId,
    required String bookId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'cached_reading_progress',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
    if (rows.isEmpty) return null;
    final json =
        jsonDecode(rows.first['progress_json'] as String) as Map<String, dynamic>;
    return ReadingProgressModel.fromJson(json).toEntity();
  }

  /// Save reading progress to cache.
  Future<void> saveReadingProgress(
    ReadingProgress progress, {
    bool isDirty = false,
  }) async {
    final db = await _db;
    final model = ReadingProgressModel.fromEntity(progress);
    await db.insert(
      'cached_reading_progress',
      {
        'id': progress.id,
        'book_id': progress.bookId,
        'user_id': progress.userId,
        'progress_json': jsonEncode(model.toJson()),
        'is_dirty': isDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all reading progress records that haven't been synced to the server.
  Future<List<Map<String, dynamic>>> getDirtyReadingProgress() async {
    final db = await _db;
    final rows = await db.query(
      'cached_reading_progress',
      where: 'is_dirty = 1',
    );
    return rows.map((row) {
      return {
        'id': row['id'] as String,
        'book_id': row['book_id'] as String,
        'user_id': row['user_id'] as String,
        'progress_json': jsonDecode(row['progress_json'] as String),
      };
    }).toList();
  }

  // ================================================================
  // INLINE ACTIVITY RESULTS
  // ================================================================

  /// Get IDs of all completed inline activities for a user + chapter.
  Future<List<String>> getCompletedInlineActivityIds({
    required String userId,
    required String chapterId,
  }) async {
    final db = await _db;
    // We need to join with cached_inline_activities to filter by chapter,
    // but inline_activity_results has no chapter_id column. Instead, we
    // look up which activity IDs belong to this chapter, then filter.
    final activityRows = await db.query(
      'cached_inline_activities',
      columns: ['id'],
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
    );
    if (activityRows.isEmpty) return [];

    final activityIds = activityRows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(activityIds.length, '?').join(', ');

    final resultRows = await db.query(
      'cached_inline_activity_results',
      columns: ['inline_activity_id'],
      where: 'user_id = ? AND inline_activity_id IN ($placeholders)',
      whereArgs: [userId, ...activityIds],
    );
    return resultRows
        .map((r) => r['inline_activity_id'] as String)
        .toList();
  }

  /// Save an inline activity result to cache.
  Future<void> saveInlineActivityResult({
    required String activityId,
    required String bookId,
    required String userId,
    required bool isCorrect,
    required int xpEarned,
    bool isDirty = false,
  }) async {
    final db = await _db;
    await db.insert(
      'cached_inline_activity_results',
      {
        'inline_activity_id': activityId,
        'book_id': bookId,
        'user_id': userId,
        'is_correct': isCorrect ? 1 : 0,
        'xp_earned': xpEarned,
        'answered_at': DateTime.now().toIso8601String(),
        'is_dirty': isDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Check whether a result already exists for an inline activity.
  Future<bool> hasInlineActivityResult(String activityId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM cached_inline_activity_results '
      'WHERE inline_activity_id = ?',
      [activityId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Get all inline activity results that haven't been synced.
  Future<List<Map<String, dynamic>>> getDirtyInlineActivityResults() async {
    final db = await _db;
    final rows = await db.query(
      'cached_inline_activity_results',
      where: 'is_dirty = 1',
    );
    return rows.map((row) {
      return {
        'inline_activity_id': row['inline_activity_id'] as String,
        'book_id': row['book_id'] as String,
        'user_id': row['user_id'] as String,
        'is_correct': (row['is_correct'] as int) == 1,
        'xp_earned': row['xp_earned'] as int,
        'answered_at': row['answered_at'] as String,
      };
    }).toList();
  }

  // ================================================================
  // LEGACY ACTIVITY RESULTS
  // ================================================================

  /// Save a legacy activity result to cache.
  Future<void> saveActivityResult(
    Map<String, dynamic> resultJson, {
    required String activityId,
    required String bookId,
    required String userId,
    bool isDirty = false,
  }) async {
    final db = await _db;
    // Use the result's own ID if available, otherwise generate one.
    final id = resultJson['id'] as String? ??
        '${userId}_${activityId}_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert(
      'cached_activity_results',
      {
        'id': id,
        'activity_id': activityId,
        'book_id': bookId,
        'user_id': userId,
        'result_json': jsonEncode(resultJson),
        'is_dirty': isDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all legacy activity results that haven't been synced.
  Future<List<Map<String, dynamic>>> getDirtyActivityResults() async {
    final db = await _db;
    final rows = await db.query(
      'cached_activity_results',
      where: 'is_dirty = 1',
    );
    return rows.map((row) {
      return {
        'id': row['id'] as String,
        'activity_id': row['activity_id'] as String,
        'book_id': row['book_id'] as String,
        'user_id': row['user_id'] as String,
        'result_json': jsonDecode(row['result_json'] as String),
      };
    }).toList();
  }

  // ================================================================
  // VOCABULARY WORDS
  // ================================================================

  /// Save vocabulary words for a book. Each word map must have a `word_id` key.
  Future<void> saveVocabularyWords(
    String bookId,
    List<Map<String, dynamic>> wordsJson,
  ) async {
    final db = await _db;
    final batch = db.batch();
    for (final word in wordsJson) {
      batch.insert(
        'cached_vocabulary_words',
        {
          'word_id': word['id'] as String? ?? word['word_id'] as String,
          'book_id': bookId,
          'word_json': jsonEncode(word),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ================================================================
  // FILE CACHE
  // ================================================================

  /// Get the local file path for a remote URL. Returns `null` if not cached.
  Future<String?> getLocalFilePath(String url) async {
    final db = await _db;
    final rows = await db.query(
      'cached_files',
      columns: ['local_path'],
      where: 'url = ?',
      whereArgs: [url],
    );
    if (rows.isEmpty) return null;
    return rows.first['local_path'] as String;
  }

  /// Record a cached file.
  Future<void> saveFile({
    required String url,
    required String bookId,
    required String localPath,
    required String fileType,
    required int fileSize,
  }) async {
    final db = await _db;
    await db.insert(
      'cached_files',
      {
        'url': url,
        'book_id': bookId,
        'local_path': localPath,
        'file_type': fileType,
        'file_size': fileSize,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the total file cache size in bytes for a single book.
  Future<int> getBookCacheSize(String bookId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(file_size), 0) as total '
      'FROM cached_files WHERE book_id = ?',
      [bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get the total file cache size in bytes across all books.
  Future<int> getTotalCacheSize() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(file_size), 0) as total FROM cached_files',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get all local file paths for a book (for cleanup when deleting cache).
  Future<List<String>> getLocalFilePathsForBook(String bookId) async {
    final db = await _db;
    final rows = await db.query(
      'cached_files',
      columns: ['local_path'],
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return rows.map((r) => r['local_path'] as String).toList();
  }

  // ================================================================
  // OFFLINE PENDING ACTIONS
  // ================================================================

  /// Queue a pending action to be replayed when connectivity returns.
  Future<void> queuePendingAction({
    required String actionType,
    required Map<String, dynamic> payload,
    required String bookId,
  }) async {
    final db = await _db;
    await db.insert('offline_pending_actions', {
      'action_type': actionType,
      'payload_json': jsonEncode(payload),
      'book_id': bookId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get all pending actions, ordered by creation time (FIFO).
  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await _db;
    final rows = await db.query(
      'offline_pending_actions',
      orderBy: 'id ASC',
    );
    return rows.map((row) {
      return {
        'id': row['id'] as int,
        'action_type': row['action_type'] as String,
        'payload': jsonDecode(row['payload_json'] as String),
        'book_id': row['book_id'] as String,
        'created_at': row['created_at'] as String,
      };
    }).toList();
  }

  /// Delete a pending action after successful replay.
  Future<void> deletePendingAction(int id) async {
    final db = await _db;
    await db.delete(
      'offline_pending_actions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ================================================================
  // DIRTY RECORD HELPERS
  // ================================================================

  /// Clear the dirty flag for a specific record in a dirty-capable table.
  ///
  /// Usage: `clearDirtyFlag('cached_reading_progress', 'id', progressId)`
  Future<void> clearDirtyFlag(
    String table,
    String idColumn,
    String id,
  ) async {
    final db = await _db;
    await db.update(
      table,
      {'is_dirty': 0},
      where: '$idColumn = ?',
      whereArgs: [id],
    );
  }
}

@Riverpod(keepAlive: true)
BookCacheStore bookCacheStore(BookCacheStoreRef ref) {
  final cacheDb = ref.watch(bookCacheDatabaseProvider);
  return BookCacheStore(cacheDb);
}
