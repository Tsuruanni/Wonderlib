# Offline Book Cache System — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add sqflite-based offline caching for books so chapter transitions are instant and books can be read without internet.

**Architecture:** Repository wrapper pattern — `CachedXxxRepository` wraps existing `SupabaseXxxRepository`, adding a sqflite cache layer. Existing UseCase/Provider/Screen layers unchanged. File cache (images/audio) on filesystem with metadata in sqflite.

**Tech Stack:** Flutter, sqflite (existing dep), Riverpod, dartz Either, Supabase (existing)

**Spec:** `docs/superpowers/specs/2026-03-17-offline-book-cache-design.md`

---

## Implementation Notes (Read Before Starting)

These notes address review findings that affect multiple tasks. Read them first.

### N1: `updatedAt` is non-nullable on `Book` and `Chapter` entities

Both `Book.updatedAt` and `Chapter.updatedAt` are `required DateTime` (not nullable). Everywhere the plan uses `entity.updatedAt?.toIso8601String() ?? ''`, replace with `entity.updatedAt.toIso8601String()`.

### N2: Repository providers use plain `Provider`, not `@riverpod`

`repository_providers.dart` uses `final xxxProvider = Provider<XxxRepository>((ref) { ... })` — NOT `@riverpod` annotation. Task 10 MUST use this same style:

```dart
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final remoteRepo = SupabaseBookRepository();
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return CachedBookRepository(remoteRepo: remoteRepo, cacheStore: cacheStore, networkInfo: networkInfo);
});
```

Same for `contentBlockRepositoryProvider`, `bookQuizRepositoryProvider`, `activityRepositoryProvider`.

### N3: `bookId` resolution for inline activity results and legacy activity results

The `BookRepository.saveInlineActivityResult()` interface has no `bookId` parameter. The `CachedBookRepository` must derive `bookId` at write time by looking up the activity's chapter, then the chapter's book:

```dart
Future<String?> _resolveBookIdForActivity(String activityId) async {
  final db = await _cacheStore._db; // or expose a helper method
  final rows = await db.rawQuery('''
    SELECT c.book_id FROM cached_inline_activities a
    INNER JOIN cached_chapters c ON a.chapter_id = c.chapter_id
    WHERE a.id = ?
  ''', [activityId]);
  return rows.isNotEmpty ? rows.first['book_id'] as String : null;
}
```

If the activity isn't in cache (e.g., book wasn't downloaded), use an empty string — the FK on `cached_inline_activity_results` should be removed (drop the FK constraint, keep `book_id` column as a best-effort tag). Same applies to `cached_activity_results`.

**Schema change:** Remove `FOREIGN KEY (book_id)` from `cached_inline_activity_results` and `cached_activity_results` in Task 4's schema. These tables don't need cascade-delete since they track user progress (not book content).

### N4: `chapterByIdProvider` fallback

After Task 2 refactors `chapterByIdProvider` to filter from `chaptersProvider`, add a fallback for when chapters aren't loaded yet:

```dart
@riverpod
Future<Chapter?> chapterById(ChapterByIdRef ref, ({String bookId, String chapterId}) params) async {
  final chapters = await ref.watch(chaptersProvider(params.bookId).future);
  return chapters.where((c) => c.id == params.chapterId).firstOrNull;
}
```

This works because `chaptersProvider` will trigger its own fetch if not cached. The `await .future` ensures we wait for it.

### N5: `BookDownloadService` needs `userId` parameter

Add `userId` as a required parameter to `downloadBook()`. This is needed for:
- Fetching reading progress (step 9)
- Fetching completed activity results (step 10)

### N6: `BookDownloadService.setDownloadStatus` ordering

`setDownloadStatus('downloading')` requires a `cached_books` row to exist. Call `getBookById()` first (which creates the row via cache-aside), THEN set status. Or use `saveBook()` directly with `downloadStatus: 'downloading'` before the full download begins.

### N7: `BookCacheStore` missing imports

Add to Task 5 imports:
```dart
import '../../data/models/book_quiz/book_quiz_result_model.dart';
import '../../domain/entities/book_quiz.dart'; // for BookQuizResult
```

### N8: Add `useContentBlocks` to Chapter `props` list

In Task 1, after adding the field to Chapter entity, also add it to the `props` getter for Equatable equality.

### N9: `cached_inline_activity_results` and `cached_activity_results` — remove FK constraints

These tables store user progress, not book content. Drop the `FOREIGN KEY (book_id)` constraint so they work even when the book cache is deleted (user may remove download but progress should persist for sync).

---

## Chunk 1: Quick Wins + Cache Database Foundation

### Task 1: Add `useContentBlocks` to Chapter Entity and Model

Eliminates the separate `chapterUsesContentBlocks()` network call. The column already exists in the DB — just not mapped.

**Files:**
- Modify: `lib/domain/entities/chapter.dart`
- Modify: `lib/data/models/book/chapter_model.dart`

- [ ] **Step 1: Add field to Chapter entity**

In `lib/domain/entities/chapter.dart`, add `useContentBlocks` field:

```dart
// Add to constructor params (after updatedAt):
this.useContentBlocks = false,

// Add field (after updatedAt field):
final bool useContentBlocks;
```

- [ ] **Step 2: Map field in ChapterModel.fromJson()**

In `lib/data/models/book/chapter_model.dart`, add to `fromJson()`:

```dart
useContentBlocks: json['use_content_blocks'] as bool? ?? false,
```

Add to model class field:

```dart
final bool useContentBlocks;
```

Add to constructor, `toJson()`, `toEntity()`, and `fromEntity()`.

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/domain/entities/chapter.dart lib/data/models/book/chapter_model.dart`
Expected: No issues

- [ ] **Step 4: Run existing tests**

Run: `flutter test test/unit/data/models/book/`
Expected: All pass (tests may need updating if they construct ChapterModel)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/chapter.dart lib/data/models/book/chapter_model.dart
git commit -m "feat: map use_content_blocks field in Chapter entity/model"
```

---

### Task 2: Fix `chapterByIdProvider` to Filter from Batch

Eliminates redundant single-chapter network call — the data is already in `chaptersProvider`.

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart`

- [ ] **Step 1: Update chapterByIdProvider**

In `lib/presentation/providers/book_provider.dart` (lines 106-113), change `chapterByIdProvider` to accept a record `({String bookId, String chapterId})` and filter from the cached batch:

```dart
@riverpod
Future<Chapter?> chapterById(ChapterByIdRef ref, ({String bookId, String chapterId}) params) async {
  final chapters = await ref.watch(chaptersProvider(params.bookId).future);
  return chapters.where((c) => c.id == params.chapterId).firstOrNull;
}
```

- [ ] **Step 2: Update all call sites**

Search for `chapterByIdProvider(` in `lib/presentation/` and update each call to pass the record:

- `reader_screen.dart`: `ref.watch(chapterByIdProvider((bookId: widget.bookId, chapterId: widget.chapterId)))`
- Any other screens using this provider

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/presentation/`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/book_provider.dart lib/presentation/screens/
git commit -m "fix: eliminate redundant chapterById network call by filtering from batch"
```

---

### Task 3: Remove Separate `use_content_blocks` Query in Reader Body

Now that `Chapter` entity has `useContentBlocks`, the separate provider call is unnecessary.

**Files:**
- Modify: `lib/presentation/widgets/reader/reader_body.dart`

- [ ] **Step 1: Replace provider watch with entity field**

In `lib/presentation/widgets/reader/reader_body.dart` (lines 186-190), the `_ChapterContent` widget watches `chapterUsesContentBlocksProvider(chapter.id)`. Replace this with reading directly from the `chapter` entity:

```dart
// Before:
// final usesContentBlocks = ref.watch(chapterUsesContentBlocksProvider(chapter.id));
// return usesContentBlocks.when(...)

// After:
if (chapter.useContentBlocks) {
  return ReaderContentBlockList(...);
} else if (chapter.content != null) {
  // Legacy plain text content
  ...
}
```

This eliminates the `AsyncValue.when()` wrapper and the loading/error states for this check, since the value is already available synchronously from the chapter entity.

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/presentation/widgets/reader/reader_body.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/reader/reader_body.dart
git commit -m "fix: read useContentBlocks from chapter entity instead of separate query"
```

---

### Task 4: Create BookCacheDatabase (sqflite Schema)

The foundation — initializes the cache database with all tables.

**Files:**
- Create: `lib/core/services/book_cache_database.dart`

- [ ] **Step 1: Write the BookCacheDatabase class**

Create `lib/core/services/book_cache_database.dart`:

```dart
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'book_cache_database.g.dart';

class BookCacheDatabase {
  static Database? _database;
  static const _dbName = 'book_cache.db';
  static const _dbVersion = 1;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE cached_books (
        book_id TEXT PRIMARY KEY,
        book_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cached_at TEXT NOT NULL,
        include_audio INTEGER DEFAULT 0,
        download_status TEXT DEFAULT 'pending'
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_chapters (
        chapter_id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        use_content_blocks INTEGER DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_content_blocks (
        id TEXT PRIMARY KEY,
        chapter_id TEXT NOT NULL,
        content_block_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES cached_chapters(chapter_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_inline_activities (
        id TEXT PRIMARY KEY,
        chapter_id TEXT NOT NULL,
        activity_json TEXT NOT NULL,
        after_paragraph_index INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES cached_chapters(chapter_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_activities (
        id TEXT PRIMARY KEY,
        chapter_id TEXT NOT NULL,
        activity_json TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES cached_chapters(chapter_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_book_quizzes (
        quiz_id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        quiz_json TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_book_quiz_results (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        result_json TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_vocabulary_words (
        word_id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        word_json TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_reading_progress (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        progress_json TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_inline_activity_results (
        inline_activity_id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        xp_earned INTEGER NOT NULL,
        answered_at TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_activity_results (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        result_json TEXT NOT NULL,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE cached_files (
        url TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        file_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE offline_pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        book_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// Delete the entire cache database (for testing or full reset)
  Future<void> deleteDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}

@Riverpod(keepAlive: true)
BookCacheDatabase bookCacheDatabase(BookCacheDatabaseRef ref) {
  return BookCacheDatabase();
}
```

- [ ] **Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/core/services/book_cache_database.dart`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/book_cache_database.dart lib/core/services/book_cache_database.g.dart
git commit -m "feat: add BookCacheDatabase with sqflite schema for offline cache"
```

---

### Task 5: Create BookCacheStore (CRUD Operations)

All read/write operations on the cache database tables.

**Files:**
- Create: `lib/core/services/book_cache_store.dart`

- [ ] **Step 1: Write the BookCacheStore class**

Create `lib/core/services/book_cache_store.dart` with methods organized by table:

```dart
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/activity/activity_model.dart';
import '../../data/models/activity/inline_activity_model.dart';
import '../../data/models/book/book_model.dart';
import '../../data/models/book/chapter_model.dart';
import '../../data/models/book/reading_progress_model.dart';
import '../../data/models/book_quiz/book_quiz_model.dart';
import '../../data/models/content/content_block_model.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_quiz.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/entities/content/content_block.dart';
import '../../domain/entities/reading_progress.dart';
import 'book_cache_database.dart';

part 'book_cache_store.g.dart';

class BookCacheStore {
  BookCacheStore(this._cacheDb);
  final BookCacheDatabase _cacheDb;

  Future<Database> get _db => _cacheDb.database;

  // ── Books ──────────────────────────────────────────────

  Future<Book?> getBook(String bookId) async {
    final db = await _db;
    final rows = await db.query('cached_books', where: 'book_id = ?', whereArgs: [bookId]);
    if (rows.isEmpty) return null;
    return BookModel.fromJson(jsonDecode(rows.first['book_json'] as String) as Map<String, dynamic>).toEntity();
  }

  Future<void> saveBook(Book book, {String? downloadStatus}) async {
    final db = await _db;
    final model = BookModel.fromEntity(book);
    await db.insert('cached_books', {
      'book_id': book.id,
      'book_json': jsonEncode(model.toJson()),
      'updated_at': book.updatedAt?.toIso8601String() ?? '',
      'cached_at': DateTime.now().toIso8601String(),
      'download_status': downloadStatus ?? 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getDownloadStatus(String bookId) async {
    final db = await _db;
    final rows = await db.query('cached_books', columns: ['download_status'], where: 'book_id = ?', whereArgs: [bookId]);
    if (rows.isEmpty) return null;
    return rows.first['download_status'] as String?;
  }

  Future<void> setDownloadStatus(String bookId, String status) async {
    final db = await _db;
    await db.update('cached_books', {'download_status': status}, where: 'book_id = ?', whereArgs: [bookId]);
  }

  Future<void> deleteBook(String bookId) async {
    final db = await _db;
    await db.delete('cached_books', where: 'book_id = ?', whereArgs: [bookId]);
  }

  Future<List<Map<String, dynamic>>> getAllCachedBooks() async {
    final db = await _db;
    return db.query('cached_books');
  }

  // ── Chapters ───────────────────────────────────────────

  Future<List<Chapter>> getChapters(String bookId) async {
    final db = await _db;
    final rows = await db.query('cached_chapters', where: 'book_id = ?', whereArgs: [bookId], orderBy: 'order_index ASC');
    if (rows.isEmpty) return [];
    return rows.map((r) {
      return ChapterModel.fromJson(jsonDecode(r['chapter_json'] as String) as Map<String, dynamic>).toEntity();
    }).toList();
  }

  Future<Chapter?> getChapterById(String chapterId) async {
    final db = await _db;
    final rows = await db.query('cached_chapters', where: 'chapter_id = ?', whereArgs: [chapterId]);
    if (rows.isEmpty) return null;
    return ChapterModel.fromJson(jsonDecode(rows.first['chapter_json'] as String) as Map<String, dynamic>).toEntity();
  }

  Future<void> saveChapters(String bookId, List<Chapter> chapters) async {
    final db = await _db;
    final batch = db.batch();
    for (final chapter in chapters) {
      final model = ChapterModel.fromEntity(chapter);
      batch.insert('cached_chapters', {
        'chapter_id': chapter.id,
        'book_id': bookId,
        'chapter_json': jsonEncode(model.toJson()),
        'updated_at': chapter.updatedAt?.toIso8601String() ?? '',
        'order_index': chapter.orderIndex,
        'use_content_blocks': chapter.useContentBlocks ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, String>> getChapterTimestamps(String bookId) async {
    final db = await _db;
    final rows = await db.query('cached_chapters', columns: ['chapter_id', 'updated_at'], where: 'book_id = ?', whereArgs: [bookId]);
    return {for (final r in rows) r['chapter_id'] as String: r['updated_at'] as String};
  }

  // ── Content Blocks ─────────────────────────────────────

  Future<List<ContentBlock>> getContentBlocks(String chapterId) async {
    final db = await _db;
    final rows = await db.query('cached_content_blocks', where: 'chapter_id = ?', whereArgs: [chapterId], orderBy: 'order_index ASC');
    if (rows.isEmpty) return [];
    return rows.map((r) {
      return ContentBlockModel.fromJson(jsonDecode(r['content_block_json'] as String) as Map<String, dynamic>).toEntity();
    }).toList();
  }

  Future<ContentBlock?> getContentBlockById(String blockId) async {
    final db = await _db;
    final rows = await db.query('cached_content_blocks', where: 'id = ?', whereArgs: [blockId]);
    if (rows.isEmpty) return null;
    return ContentBlockModel.fromJson(jsonDecode(rows.first['content_block_json'] as String) as Map<String, dynamic>).toEntity();
  }

  Future<void> saveContentBlocks(String chapterId, List<ContentBlock> blocks) async {
    final db = await _db;
    // Delete old blocks for this chapter first, then insert fresh
    await db.delete('cached_content_blocks', where: 'chapter_id = ?', whereArgs: [chapterId]);
    final batch = db.batch();
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
  }

  // ── Inline Activities ──────────────────────────────────

  Future<List<InlineActivity>> getInlineActivities(String chapterId) async {
    final db = await _db;
    final rows = await db.query('cached_inline_activities', where: 'chapter_id = ?', whereArgs: [chapterId], orderBy: 'after_paragraph_index ASC');
    if (rows.isEmpty) return [];
    return rows.map((r) {
      return InlineActivityModel.fromJson(jsonDecode(r['activity_json'] as String) as Map<String, dynamic>).toEntity();
    }).toList();
  }

  Future<void> saveInlineActivities(String chapterId, List<InlineActivity> activities) async {
    final db = await _db;
    await db.delete('cached_inline_activities', where: 'chapter_id = ?', whereArgs: [chapterId]);
    final batch = db.batch();
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
  }

  // ── Legacy Activities ──────────────────────────────────

  Future<List<Activity>> getActivities(String chapterId) async {
    final db = await _db;
    final rows = await db.query('cached_activities', where: 'chapter_id = ?', whereArgs: [chapterId], orderBy: 'order_index ASC');
    if (rows.isEmpty) return [];
    return rows.map((r) {
      return ActivityModel.fromJson(jsonDecode(r['activity_json'] as String) as Map<String, dynamic>).toEntity();
    }).toList();
  }

  Future<Activity?> getActivityById(String activityId) async {
    final db = await _db;
    final rows = await db.query('cached_activities', where: 'id = ?', whereArgs: [activityId]);
    if (rows.isEmpty) return null;
    return ActivityModel.fromJson(jsonDecode(rows.first['activity_json'] as String) as Map<String, dynamic>).toEntity();
  }

  Future<void> saveActivities(String chapterId, List<Activity> activities) async {
    final db = await _db;
    await db.delete('cached_activities', where: 'chapter_id = ?', whereArgs: [chapterId]);
    final batch = db.batch();
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
  }

  // ── Book Quizzes ───────────────────────────────────────

  Future<BookQuiz?> getQuizForBook(String bookId) async {
    final db = await _db;
    final rows = await db.query('cached_book_quizzes', where: 'book_id = ?', whereArgs: [bookId]);
    if (rows.isEmpty) return null;
    return BookQuizModel.fromJson(jsonDecode(rows.first['quiz_json'] as String) as Map<String, dynamic>).toEntity();
  }

  Future<bool> bookHasQuiz(String bookId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cached_book_quizzes WHERE book_id = ?', [bookId]));
    return (count ?? 0) > 0;
  }

  Future<void> saveQuiz(String bookId, BookQuiz quiz) async {
    final db = await _db;
    final model = BookQuizModel.fromEntity(quiz);
    await db.insert('cached_book_quizzes', {
      'quiz_id': quiz.id,
      'book_id': bookId,
      'quiz_json': jsonEncode(model.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Book Quiz Results ──────────────────────────────────

  Future<void> saveQuizResult(BookQuizResult result, String bookId, {bool isDirty = false}) async {
    final db = await _db;
    final model = BookQuizResultModel.fromEntity(result);
    await db.insert('cached_book_quiz_results', {
      'id': result.id,
      'quiz_id': result.quizId,
      'book_id': bookId,
      'user_id': result.userId,
      'result_json': jsonEncode(model.toJson()),
      'is_dirty': isDirty ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<BookQuizResult?> getBestQuizResult({required String userId, required String bookId}) async {
    final db = await _db;
    final rows = await db.query('cached_book_quiz_results', where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId], orderBy: 'CAST(json_extract(result_json, "\$.score") AS REAL) DESC', limit: 1);
    if (rows.isEmpty) return null;
    return BookQuizResultModel.fromJson(jsonDecode(rows.first['result_json'] as String) as Map<String, dynamic>).toEntity();
  }

  Future<List<BookQuizResult>> getUserQuizResults({required String userId, required String bookId}) async {
    final db = await _db;
    final rows = await db.query('cached_book_quiz_results', where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId]);
    return rows.map((r) => BookQuizResultModel.fromJson(jsonDecode(r['result_json'] as String) as Map<String, dynamic>).toEntity()).toList();
  }

  // ── Reading Progress ───────────────────────────────────

  Future<ReadingProgress?> getReadingProgress({required String userId, required String bookId}) async {
    final db = await _db;
    final id = '${userId}_$bookId';
    final rows = await db.query('cached_reading_progress', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ReadingProgressModel.fromJson(jsonDecode(rows.first['progress_json'] as String) as Map<String, dynamic>).toEntity();
  }

  Future<void> saveReadingProgress(ReadingProgress progress, {bool isDirty = false}) async {
    final db = await _db;
    final model = ReadingProgressModel.fromEntity(progress);
    final id = '${progress.userId}_${progress.bookId}';
    await db.insert('cached_reading_progress', {
      'id': id,
      'book_id': progress.bookId,
      'user_id': progress.userId,
      'progress_json': jsonEncode(model.toJson()),
      'is_dirty': isDirty ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getDirtyReadingProgress() async {
    final db = await _db;
    return db.query('cached_reading_progress', where: 'is_dirty = 1');
  }

  // ── Inline Activity Results ────────────────────────────

  Future<List<String>> getCompletedInlineActivityIds({required String userId, required String chapterId}) async {
    final db = await _db;
    // Join with cached_inline_activities to filter by chapter
    final rows = await db.rawQuery('''
      SELECT r.inline_activity_id
      FROM cached_inline_activity_results r
      INNER JOIN cached_inline_activities a ON r.inline_activity_id = a.id
      WHERE r.user_id = ? AND a.chapter_id = ?
    ''', [userId, chapterId]);
    return rows.map((r) => r['inline_activity_id'] as String).toList();
  }

  Future<void> saveInlineActivityResult({
    required String activityId,
    required String bookId,
    required String userId,
    required bool isCorrect,
    required int xpEarned,
    bool isDirty = false,
  }) async {
    final db = await _db;
    await db.insert('cached_inline_activity_results', {
      'inline_activity_id': activityId,
      'book_id': bookId,
      'user_id': userId,
      'is_correct': isCorrect ? 1 : 0,
      'xp_earned': xpEarned,
      'answered_at': DateTime.now().toIso8601String(),
      'is_dirty': isDirty ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore); // Ignore duplicates
  }

  Future<bool> hasInlineActivityResult(String activityId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cached_inline_activity_results WHERE inline_activity_id = ?', [activityId]));
    return (count ?? 0) > 0;
  }

  Future<List<Map<String, dynamic>>> getDirtyInlineActivityResults() async {
    final db = await _db;
    return db.query('cached_inline_activity_results', where: 'is_dirty = 1');
  }

  // ── Legacy Activity Results ────────────────────────────

  Future<void> saveActivityResult(Map<String, dynamic> resultJson, {required String activityId, required String bookId, required String userId, bool isDirty = false}) async {
    final db = await _db;
    final id = resultJson['id'] as String? ?? '${userId}_$activityId';
    await db.insert('cached_activity_results', {
      'id': id,
      'activity_id': activityId,
      'book_id': bookId,
      'user_id': userId,
      'result_json': jsonEncode(resultJson),
      'is_dirty': isDirty ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getDirtyActivityResults() async {
    final db = await _db;
    return db.query('cached_activity_results', where: 'is_dirty = 1');
  }

  // ── Vocabulary Words ───────────────────────────────────

  Future<void> saveVocabularyWords(String bookId, List<Map<String, dynamic>> wordsJson) async {
    final db = await _db;
    final batch = db.batch();
    for (final wordJson in wordsJson) {
      batch.insert('cached_vocabulary_words', {
        'word_id': wordJson['id'] as String,
        'book_id': bookId,
        'word_json': jsonEncode(wordJson),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── File Cache ─────────────────────────────────────────

  Future<String?> getLocalFilePath(String url) async {
    final db = await _db;
    final rows = await db.query('cached_files', columns: ['local_path'], where: 'url = ?', whereArgs: [url]);
    if (rows.isEmpty) return null;
    return rows.first['local_path'] as String?;
  }

  Future<void> saveFile({required String url, required String bookId, required String localPath, required String fileType, required int fileSize}) async {
    final db = await _db;
    await db.insert('cached_files', {
      'url': url,
      'book_id': bookId,
      'local_path': localPath,
      'file_type': fileType,
      'file_size': fileSize,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getBookCacheSize(String bookId) async {
    final db = await _db;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(file_size), 0) FROM cached_files WHERE book_id = ?', [bookId]));
    return result ?? 0;
  }

  Future<int> getTotalCacheSize() async {
    final db = await _db;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(SUM(file_size), 0) FROM cached_files'));
    return result ?? 0;
  }

  Future<List<String>> getLocalFilePathsForBook(String bookId) async {
    final db = await _db;
    final rows = await db.query('cached_files', columns: ['local_path'], where: 'book_id = ?', whereArgs: [bookId]);
    return rows.map((r) => r['local_path'] as String).toList();
  }

  // ── Offline Pending Actions ────────────────────────────

  Future<void> queuePendingAction({required String actionType, required Map<String, dynamic> payload, required String bookId}) async {
    final db = await _db;
    await db.insert('offline_pending_actions', {
      'action_type': actionType,
      'payload_json': jsonEncode(payload),
      'book_id': bookId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await _db;
    return db.query('offline_pending_actions', orderBy: 'id ASC');
  }

  Future<void> deletePendingAction(int id) async {
    final db = await _db;
    await db.delete('offline_pending_actions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Dirty Record Helpers ───────────────────────────────

  Future<void> clearDirtyFlag(String table, String idColumn, String id) async {
    final db = await _db;
    await db.update(table, {'is_dirty': 0}, where: '$idColumn = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDirtyQuizResults() async {
    final db = await _db;
    return db.query('cached_book_quiz_results', where: 'is_dirty = 1');
  }
}

@Riverpod(keepAlive: true)
BookCacheStore bookCacheStore(BookCacheStoreRef ref) {
  final cacheDb = ref.watch(bookCacheDatabaseProvider);
  return BookCacheStore(cacheDb);
}
```

**Important:** This file references model classes that must have `fromEntity()` and `toJson()` methods. Verify these exist before using. The exact method signatures may need adjusting based on the actual model implementations — read each model file during implementation to confirm.

- [ ] **Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/core/services/book_cache_store.dart`
Expected: No issues (may need import adjustments based on actual model/entity paths)

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/book_cache_store.dart lib/core/services/book_cache_store.g.dart
git commit -m "feat: add BookCacheStore with CRUD operations for all cache tables"
```

---

## Chunk 2: Cached Repository Wrappers

### Task 6: Create CachedBookRepository

Wraps `SupabaseBookRepository`. 21 methods: 6 cache-aside, 4 write-through, 11 pass-through.

**Files:**
- Create: `lib/data/repositories/cached/cached_book_repository.dart`

- [ ] **Step 1: Write CachedBookRepository**

Create `lib/data/repositories/cached/cached_book_repository.dart`:

This class implements `BookRepository` and delegates to both `BookCacheStore` (local) and `SupabaseBookRepository` (remote). Follow the method classification from the spec:

- **Cache-aside methods** (`getBookById`, `getChapters`, `getChapterById`, `getReadingProgress`, `getInlineActivities`, `getCompletedInlineActivities`): Check cache first, fall back to remote, write result to cache.
- **Write-through methods** (`updateReadingProgress`, `updateCurrentChapter`, `saveInlineActivityResult`, `markChapterComplete`): Write to both cache and remote if online; cache-only with `is_dirty=1` if offline.
- **Pass-through methods** (remaining 11): Delegate directly to remote repository.

Key implementation details:
- Constructor takes `SupabaseBookRepository`, `BookCacheStore`, and `NetworkInfo`
- `markChapterComplete` offline mode: read all data from cache, calculate locally, queue pending actions for XP/assignments/daily log
- Background freshness check: fire-and-forget using `_remoteRepo.getChapters()` to compare `updated_at` timestamps

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/unit_book.dart';
import '../../../domain/repositories/book_repository.dart';
import '../supabase/supabase_book_repository.dart';

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

  // ── Cache-aside methods ────────────────────────────────

  @override
  Future<Either<Failure, Book>> getBookById(String id) async {
    final cached = await _cacheStore.getBook(id);
    if (cached != null) return Right(cached);

    final result = await _remoteRepo.getBookById(id);
    result.fold((_) {}, (book) => _cacheStore.saveBook(book));
    return result;
  }

  @override
  Future<Either<Failure, List<Chapter>>> getChapters(String bookId) async {
    final cached = await _cacheStore.getChapters(bookId);
    if (cached.isNotEmpty) {
      // Fire-and-forget freshness check
      _checkChapterFreshness(bookId);
      return Right(cached);
    }

    final result = await _remoteRepo.getChapters(bookId);
    result.fold((_) {}, (chapters) => _cacheStore.saveChapters(bookId, chapters));
    return result;
  }

  @override
  Future<Either<Failure, Chapter>> getChapterById(String chapterId) async {
    final cached = await _cacheStore.getChapterById(chapterId);
    if (cached != null) return Right(cached);

    final result = await _remoteRepo.getChapterById(chapterId);
    // Note: saving single chapter needs bookId — extract from result
    result.fold((_) {}, (chapter) => _cacheStore.saveChapters(chapter.bookId, [chapter]));
    return result;
  }

  @override
  Future<Either<Failure, ReadingProgress>> getReadingProgress({
    required String userId,
    required String bookId,
  }) async {
    final cached = await _cacheStore.getReadingProgress(userId: userId, bookId: bookId);
    if (cached != null) return Right(cached);

    final result = await _remoteRepo.getReadingProgress(userId: userId, bookId: bookId);
    result.fold((_) {}, (progress) => _cacheStore.saveReadingProgress(progress));
    return result;
  }

  @override
  Future<Either<Failure, List<InlineActivity>>> getInlineActivities(String chapterId) async {
    final cached = await _cacheStore.getInlineActivities(chapterId);
    if (cached.isNotEmpty) return Right(cached);

    final result = await _remoteRepo.getInlineActivities(chapterId);
    result.fold((_) {}, (activities) => _cacheStore.saveInlineActivities(chapterId, activities));
    return result;
  }

  @override
  Future<Either<Failure, List<String>>> getCompletedInlineActivities({
    required String userId,
    required String chapterId,
  }) async {
    final cached = await _cacheStore.getCompletedInlineActivityIds(userId: userId, chapterId: chapterId);
    if (cached.isNotEmpty) return Right(cached);

    final result = await _remoteRepo.getCompletedInlineActivities(userId: userId, chapterId: chapterId);
    return result;
  }

  // ── Write-through methods ──────────────────────────────

  @override
  Future<Either<Failure, ReadingProgress>> updateReadingProgress(ReadingProgress progress) async {
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      final result = await _remoteRepo.updateReadingProgress(progress);
      result.fold((_) {}, (p) => _cacheStore.saveReadingProgress(p));
      return result;
    }
    // Offline: save locally with dirty flag
    await _cacheStore.saveReadingProgress(progress, isDirty: true);
    return Right(progress);
  }

  @override
  Future<Either<Failure, void>> updateCurrentChapter({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      return _remoteRepo.updateCurrentChapter(userId: userId, bookId: bookId, chapterId: chapterId);
    }
    // Offline: update cached reading progress
    final cached = await _cacheStore.getReadingProgress(userId: userId, bookId: bookId);
    if (cached != null) {
      final updated = cached.copyWith(chapterId: chapterId);
      await _cacheStore.saveReadingProgress(updated, isDirty: true);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, bool>> saveInlineActivityResult({
    required String userId,
    required String activityId,
    required bool isCorrect,
    required int xpEarned,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      final result = await _remoteRepo.saveInlineActivityResult(
        userId: userId, activityId: activityId, isCorrect: isCorrect, xpEarned: xpEarned,
      );
      result.fold((_) {}, (isNew) {
        // Cache the result regardless
        _cacheStore.saveInlineActivityResult(
          activityId: activityId, bookId: '', userId: userId,
          isCorrect: isCorrect, xpEarned: xpEarned,
        );
      });
      return result;
    }
    // Offline: check if already exists, save with dirty flag
    final exists = await _cacheStore.hasInlineActivityResult(activityId);
    if (exists) return const Right(false);
    await _cacheStore.saveInlineActivityResult(
      activityId: activityId, bookId: '', userId: userId,
      isCorrect: isCorrect, xpEarned: xpEarned, isDirty: true,
    );
    return const Right(true); // Optimistic
  }

  @override
  Future<Either<Failure, ReadingProgress>> markChapterComplete({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      final result = await _remoteRepo.markChapterComplete(userId: userId, bookId: bookId, chapterId: chapterId);
      result.fold((_) {}, (progress) => _cacheStore.saveReadingProgress(progress));
      return result;
    }
    // Offline: calculate locally
    return _markChapterCompleteOffline(userId: userId, bookId: bookId, chapterId: chapterId);
  }

  Future<Either<Failure, ReadingProgress>> _markChapterCompleteOffline({
    required String userId,
    required String bookId,
    required String chapterId,
  }) async {
    try {
      final progress = await _cacheStore.getReadingProgress(userId: userId, bookId: bookId);
      final chapters = await _cacheStore.getChapters(bookId);
      final hasQuiz = await _cacheStore.bookHasQuiz(bookId);

      if (progress == null || chapters.isEmpty) {
        return const Left(CacheFailure('No cached data for offline completion'));
      }

      final completedIds = {...progress.completedChapterIds, chapterId};
      final percentage = (completedIds.length / chapters.length * 100).round();
      final allChaptersDone = completedIds.length >= chapters.length;
      final isCompleted = allChaptersDone && (!hasQuiz || progress.quizPassed);

      final updated = progress.copyWith(
        completedChapterIds: completedIds.toList(),
        completionPercentage: percentage,
        isCompleted: isCompleted,
      );

      await _cacheStore.saveReadingProgress(updated, isDirty: true);

      // Queue pending actions
      await _cacheStore.queuePendingAction(
        actionType: 'award_xp',
        payload: {'userId': userId, 'bookId': bookId, 'chapterId': chapterId},
        bookId: bookId,
      );
      await _cacheStore.queuePendingAction(
        actionType: 'log_daily_read',
        payload: {'userId': userId, 'chapterId': chapterId},
        bookId: bookId,
      );

      return Right(updated);
    } catch (e) {
      return Left(CacheFailure('Offline completion failed: $e'));
    }
  }

  // ── Pass-through methods ───────────────────────────────

  @override
  Future<Either<Failure, List<Book>>> getBooks({String? level, String? genre, String? ageGroup, int page = 1, int pageSize = 20}) =>
      _remoteRepo.getBooks(level: level, genre: genre, ageGroup: ageGroup, page: page, pageSize: pageSize);

  @override
  Future<Either<Failure, List<Book>>> searchBooks(String query) => _remoteRepo.searchBooks(query);

  @override
  Future<Either<Failure, List<Book>>> getRecommendedBooks(String userId) => _remoteRepo.getRecommendedBooks(userId);

  @override
  Future<Either<Failure, List<Book>>> getContinueReading(String userId) => _remoteRepo.getContinueReading(userId);

  @override
  Future<Either<Failure, List<ReadingProgress>>> getUserReadingHistory(String userId) => _remoteRepo.getUserReadingHistory(userId);

  @override
  Future<Either<Failure, Set<String>>> getCompletedBookIds(String userId) => _remoteRepo.getCompletedBookIds(userId);

  @override
  Future<Either<Failure, bool>> hasReadToday(String userId) => _remoteRepo.hasReadToday(userId);

  @override
  Future<Either<Failure, int>> getCorrectAnswersTodayCount(String userId) => _remoteRepo.getCorrectAnswersTodayCount(userId);

  @override
  Future<Either<Failure, int>> getWordsReadTodayCount(String userId) => _remoteRepo.getWordsReadTodayCount(userId);

  @override
  Future<Either<Failure, List<UnitBook>>> getUnitBooks(String userId) => _remoteRepo.getUnitBooks(userId);

  // ── Background freshness check ─────────────────────────

  Future<void> _checkChapterFreshness(String bookId) async {
    try {
      if (!await _networkInfo.isConnected) return;
      final remoteResult = await _remoteRepo.getChapters(bookId);
      remoteResult.fold((_) {}, (remoteChapters) async {
        final localTimestamps = await _cacheStore.getChapterTimestamps(bookId);
        for (final chapter in remoteChapters) {
          final localTs = localTimestamps[chapter.id];
          if (localTs == null || chapter.updatedAt?.toIso8601String() != localTs) {
            await _cacheStore.saveChapters(bookId, [chapter]);
          }
        }
      });
    } catch (_) {
      // Silently ignore — freshness check is best-effort
    }
  }
}
```

**Note:** The `CacheFailure` class may need to be created if it doesn't exist in `lib/core/errors/failures.dart`. Check the existing failure types and use an appropriate one or create a new one.

**Note:** The `ReadingProgress.copyWith` method may not exist — check the entity and add if needed.

- [ ] **Step 2: Verify model/entity compatibility**

Read these files to confirm `fromEntity()`, `toEntity()`, `copyWith()` methods exist:
- `lib/data/models/book/reading_progress_model.dart`
- `lib/domain/entities/reading_progress.dart`
- `lib/core/errors/failures.dart`

Add any missing methods (e.g., `ReadingProgress.copyWith`, `CacheFailure` class).

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/data/repositories/cached/cached_book_repository.dart`
Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/data/repositories/cached/cached_book_repository.dart
git commit -m "feat: add CachedBookRepository with cache-aside/write-through/pass-through methods"
```

---

### Task 7: Create CachedContentBlockRepository

Wraps `SupabaseContentBlockRepository`. 3 methods: 2 cache-aside, 1 reads from chapter cache.

**Files:**
- Create: `lib/data/repositories/cached/cached_content_block_repository.dart`

- [ ] **Step 1: Write CachedContentBlockRepository**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/content/content_block.dart';
import '../../../domain/repositories/content_block_repository.dart';
import '../supabase/supabase_content_block_repository.dart';

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

  @override
  Future<Either<Failure, List<ContentBlock>>> getContentBlocks(String chapterId) async {
    final cached = await _cacheStore.getContentBlocks(chapterId);
    if (cached.isNotEmpty) return Right(cached);

    final result = await _remoteRepo.getContentBlocks(chapterId);
    result.fold((_) {}, (blocks) => _cacheStore.saveContentBlocks(chapterId, blocks));
    return result;
  }

  @override
  Future<Either<Failure, ContentBlock>> getContentBlockById(String blockId) async {
    final cached = await _cacheStore.getContentBlockById(blockId);
    if (cached != null) return Right(cached);

    return _remoteRepo.getContentBlockById(blockId);
  }

  @override
  Future<Either<Failure, bool>> chapterUsesContentBlocks(String chapterId) async {
    // Read from cached chapter data if available
    final cachedChapter = await _cacheStore.getChapterById(chapterId);
    if (cachedChapter != null) return Right(cachedChapter.useContentBlocks);

    // Fall back to remote
    return _remoteRepo.chapterUsesContentBlocks(chapterId);
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/data/repositories/cached/cached_content_block_repository.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/cached/cached_content_block_repository.dart
git commit -m "feat: add CachedContentBlockRepository"
```

---

### Task 8: Create CachedBookQuizRepository

Wraps `SupabaseBookQuizRepository`. 6 methods: 4 cache-aside, 1 write-through, 1 pass-through.

**Files:**
- Create: `lib/data/repositories/cached/cached_book_quiz_repository.dart`

- [ ] **Step 1: Write CachedBookQuizRepository**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/book_quiz.dart';
import '../../../domain/repositories/book_quiz_repository.dart';
import '../supabase/supabase_book_quiz_repository.dart';

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

  @override
  Future<Either<Failure, BookQuiz?>> getQuizForBook(String bookId) async {
    final cached = await _cacheStore.getQuizForBook(bookId);
    if (cached != null) return Right(cached);

    final result = await _remoteRepo.getQuizForBook(bookId);
    result.fold((_) {}, (quiz) {
      if (quiz != null) _cacheStore.saveQuiz(bookId, quiz);
    });
    return result;
  }

  @override
  Future<Either<Failure, bool>> bookHasQuiz(String bookId) async {
    final hasCached = await _cacheStore.bookHasQuiz(bookId);
    if (hasCached) return const Right(true);

    return _remoteRepo.bookHasQuiz(bookId);
  }

  @override
  Future<Either<Failure, BookQuizResult>> submitQuizResult(BookQuizResult result) async {
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      final remoteResult = await _remoteRepo.submitQuizResult(result);
      remoteResult.fold((_) {}, (r) => _cacheStore.saveQuizResult(r, result.bookId));
      return remoteResult;
    }
    // Offline: save with dirty flag
    await _cacheStore.saveQuizResult(result, result.bookId, isDirty: true);
    return Right(result);
  }

  @override
  Future<Either<Failure, BookQuizResult?>> getBestResult({
    required String userId,
    required String bookId,
  }) async {
    final cached = await _cacheStore.getBestQuizResult(userId: userId, bookId: bookId);
    if (cached != null) return Right(cached);

    final result = await _remoteRepo.getBestResult(userId: userId, bookId: bookId);
    result.fold((_) {}, (r) {
      if (r != null) _cacheStore.saveQuizResult(r, bookId);
    });
    return result;
  }

  @override
  Future<Either<Failure, List<BookQuizResult>>> getUserQuizResults({
    required String userId,
    required String bookId,
  }) async {
    final cached = await _cacheStore.getUserQuizResults(userId: userId, bookId: bookId);
    if (cached.isNotEmpty) return Right(cached);

    final result = await _remoteRepo.getUserQuizResults(userId: userId, bookId: bookId);
    result.fold((_) {}, (results) {
      for (final r in results) {
        _cacheStore.saveQuizResult(r, bookId);
      }
    });
    return result;
  }

  @override
  Future<Either<Failure, List<StudentQuizProgress>>> getStudentQuizResults(String studentId) =>
      _remoteRepo.getStudentQuizResults(studentId);
}
```

**Note:** `BookQuizResult.bookId` may not exist on the entity. Check `lib/domain/entities/book_quiz.dart` — if missing, use the `bookId` parameter passed to methods instead.

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/data/repositories/cached/cached_book_quiz_repository.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/cached/cached_book_quiz_repository.dart
git commit -m "feat: add CachedBookQuizRepository"
```

---

### Task 9: Create CachedActivityRepository

Wraps `SupabaseActivityRepository`. 6 methods: 4 cache-aside, 1 write-through, 1 pass-through.

**Files:**
- Create: `lib/data/repositories/cached/cached_activity_repository.dart`

- [ ] **Step 1: Write CachedActivityRepository**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../core/services/book_cache_store.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../supabase/supabase_activity_repository.dart';

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

  @override
  Future<Either<Failure, List<Activity>>> getActivitiesByChapter(String chapterId) async {
    final cached = await _cacheStore.getActivities(chapterId);
    if (cached.isNotEmpty) return Right(cached);

    final result = await _remoteRepo.getActivitiesByChapter(chapterId);
    result.fold((_) {}, (activities) => _cacheStore.saveActivities(chapterId, activities));
    return result;
  }

  @override
  Future<Either<Failure, Activity>> getActivityById(String id) async {
    final cached = await _cacheStore.getActivityById(id);
    if (cached != null) return Right(cached);

    return _remoteRepo.getActivityById(id);
  }

  @override
  Future<Either<Failure, ActivityResult>> submitActivityResult(ActivityResult result) async {
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      final remoteResult = await _remoteRepo.submitActivityResult(result);
      // Cache on success if needed
      return remoteResult;
    }
    // Offline: save with dirty flag
    // Note: ActivityResult needs to be serialized — check model for toJson()
    await _cacheStore.saveActivityResult(
      {'id': result.id, 'activity_id': result.activityId, 'user_id': result.userId},
      activityId: result.activityId,
      bookId: '', // bookId not available on ActivityResult — may need to pass through context
      userId: result.userId,
      isDirty: true,
    );
    return Right(result);
  }

  @override
  Future<Either<Failure, List<ActivityResult>>> getUserActivityResults({
    required String userId,
    String? activityId,
  }) => _remoteRepo.getUserActivityResults(userId: userId, activityId: activityId);

  @override
  Future<Either<Failure, ActivityResult?>> getBestResult({
    required String userId,
    required String activityId,
  }) => _remoteRepo.getBestResult(userId: userId, activityId: activityId);

  @override
  Future<Either<Failure, Map<String, dynamic>>> getActivityStats(String userId) =>
      _remoteRepo.getActivityStats(userId);
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/data/repositories/cached/cached_activity_repository.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/cached/cached_activity_repository.dart
git commit -m "feat: add CachedActivityRepository"
```

---

### Task 10: Swap Repository Providers

Wire up cached wrappers in the provider layer.

**Files:**
- Modify: `lib/presentation/providers/repository_providers.dart`

- [ ] **Step 1: Read current repository_providers.dart**

Read `lib/presentation/providers/repository_providers.dart` to understand the exact provider structure and imports.

- [ ] **Step 2: Update providers to use cached wrappers**

For each of the 4 cached repositories, wrap the existing Supabase implementation:

```dart
// Before:
// @riverpod
// BookRepository bookRepository(BookRepositoryRef ref) {
//   return SupabaseBookRepository(...);
// }

// After:
@riverpod
BookRepository bookRepository(BookRepositoryRef ref) {
  final remoteRepo = SupabaseBookRepository(...);  // existing construction
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return CachedBookRepository(
    remoteRepo: remoteRepo,
    cacheStore: cacheStore,
    networkInfo: networkInfo,
  );
}
```

Apply same pattern for `contentBlockRepository`, `bookQuizRepository`, `activityRepository`.

- [ ] **Step 3: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run analyze**

Run: `dart analyze lib/`
Expected: No issues

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/repository_providers.dart lib/presentation/providers/repository_providers.g.dart
git commit -m "feat: swap repository providers to use cached wrappers"
```

---

## Chunk 3: File Cache + Download Service

### Task 11: Create FileCacheService

Handles downloading and caching images/audio files to the filesystem.

**Files:**
- Create: `lib/core/services/file_cache_service.dart`

- [ ] **Step 1: Write FileCacheService**

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'book_cache_store.dart';

part 'file_cache_service.g.dart';

class FileCacheService {
  FileCacheService(this._cacheStore);
  final BookCacheStore _cacheStore;

  String? _baseDirPath;

  Future<String> get _baseDir async {
    if (_baseDirPath != null) return _baseDirPath!;
    final dir = await getApplicationDocumentsDirectory();
    _baseDirPath = p.join(dir.path, 'book_cache');
    await Directory(_baseDirPath!).create(recursive: true);
    return _baseDirPath!;
  }

  /// Download a file and cache it locally. Returns the local file path.
  Future<String> getOrDownload(String remoteUrl, String bookId, String fileType) async {
    // 1. Check if already cached
    final existingPath = await _cacheStore.getLocalFilePath(remoteUrl);
    if (existingPath != null && File(existingPath).existsSync()) {
      return existingPath;
    }

    // 2. Download
    final response = await http.get(Uri.parse(remoteUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    // 3. Save to filesystem
    final base = await _baseDir;
    final bookDir = p.join(base, bookId);
    await Directory(bookDir).create(recursive: true);

    final hash = md5.convert(utf8.encode(remoteUrl)).toString();
    final ext = p.extension(Uri.parse(remoteUrl).path);
    final localPath = p.join(bookDir, '$hash$ext');
    await File(localPath).writeAsBytes(response.bodyBytes);

    // 4. Record in DB
    await _cacheStore.saveFile(
      url: remoteUrl,
      bookId: bookId,
      localPath: localPath,
      fileType: fileType,
      fileSize: response.bodyBytes.length,
    );

    return localPath;
  }

  /// Resolve a remote URL to a local path if cached, else return original URL.
  Future<String> resolveUrl(String remoteUrl) async {
    final localPath = await _cacheStore.getLocalFilePath(remoteUrl);
    if (localPath != null && File(localPath).existsSync()) return localPath;
    return remoteUrl;
  }

  /// Delete all cached files for a book from filesystem.
  Future<void> deleteBookFiles(String bookId) async {
    final base = await _baseDir;
    final bookDir = Directory(p.join(base, bookId));
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }
}

@Riverpod(keepAlive: true)
FileCacheService fileCacheService(FileCacheServiceRef ref) {
  final cacheStore = ref.watch(bookCacheStoreProvider);
  return FileCacheService(cacheStore);
}
```

**Note:** Check if `http` and `crypto` packages are already in `pubspec.yaml`. If not, add them. The `http` package is commonly used in Flutter — `crypto` provides the `md5` hash.

- [ ] **Step 2: Add dependencies if needed**

Run: `grep -q "crypto:" pubspec.yaml || flutter pub add crypto`
Run: `grep -q "  http:" pubspec.yaml || flutter pub add http`

- [ ] **Step 3: Run code generation + analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && dart analyze lib/core/services/file_cache_service.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/file_cache_service.dart lib/core/services/file_cache_service.g.dart pubspec.yaml pubspec.lock
git commit -m "feat: add FileCacheService for image/audio local caching"
```

---

### Task 12: Create CachedBookImage Widget

Cache-aware image widget that checks local files first.

**Files:**
- Create: `lib/presentation/widgets/common/cached_book_image.dart`

- [ ] **Step 1: Write CachedBookImage**

```dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_cache_service.dart';

class CachedBookImage extends ConsumerWidget {
  const CachedBookImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    final fileCacheService = ref.watch(fileCacheServiceProvider);

    return FutureBuilder<String>(
      future: fileCacheService.resolveUrl(imageUrl!),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data ?? imageUrl!;

        // Local file
        if (resolvedUrl.startsWith('/')) {
          return Image.file(
            File(resolvedUrl),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => errorWidget ?? const Icon(Icons.broken_image),
          );
        }

        // Remote URL — use CachedNetworkImage as fallback
        return CachedNetworkImage(
          imageUrl: resolvedUrl,
          width: width,
          height: height,
          fit: fit,
          placeholder: (_, __) => placeholder ?? const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, __, ___) => errorWidget ?? const Icon(Icons.broken_image),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/presentation/widgets/common/cached_book_image.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/cached_book_image.dart
git commit -m "feat: add CachedBookImage widget for offline image support"
```

---

### Task 13: Audio URL Rewriting

Modify audio playback to resolve cached file paths.

**Files:**
- Modify: `lib/presentation/providers/audio_sync_provider.dart`

- [ ] **Step 1: Read audio_sync_provider.dart**

Read the file to find all places where audio URLs are set for playback (e.g., `player.setUrl(...)`, `setAudioSource(...)`).

- [ ] **Step 2: Add FileCacheService dependency and resolve URLs**

In the `AudioSyncController` class:
1. Add `FileCacheService` as a constructor parameter (injected via Riverpod)
2. Before every `setUrl(audioUrl)` call, resolve: `final resolved = await _fileCacheService.resolveUrl(audioUrl);`
3. Use `resolved` instead of the original URL

For local file paths (starting with `/`), the audio player can use `setFilePath()` or `setUrl('file://$path')` depending on the audio library.

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/presentation/providers/audio_sync_provider.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/audio_sync_provider.dart
git commit -m "feat: resolve audio URLs through file cache for offline playback"
```

---

### Task 14: Create BookDownloadService

Orchestrates downloading all book data in the background.

**Files:**
- Create: `lib/core/services/book_download_service.dart`

- [ ] **Step 1: Write BookDownloadService**

```dart
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/repositories/activity_repository.dart';
import '../../domain/repositories/book_quiz_repository.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/repositories/content_block_repository.dart';
import 'book_cache_store.dart';
import 'file_cache_service.dart';

part 'book_download_service.g.dart';

/// Progress callback: (completed steps, total steps)
typedef DownloadProgressCallback = void Function(int completed, int total);

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

  /// Download all book content for offline reading.
  /// [onProgress] receives (completedSteps, totalSteps).
  /// Returns true on success, false on failure.
  Future<bool> downloadBook(
    String bookId, {
    required String userId,
    bool includeAudio = false,
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // Step 1: Book metadata (creates cached_books row via cache-aside)
      final bookResult = await _bookRepo.getBookById(bookId);
      // NOW set download status (row exists)
      await _cacheStore.setDownloadStatus(bookId, 'downloading');
      int completed = 1;

      // Step 2: All chapters
      final chaptersResult = await _bookRepo.getChapters(bookId);
      final chapters = chaptersResult.fold((_) => <dynamic>[], (c) => c);
      completed++;

      // Estimate total steps
      final totalSteps = 2 + // book + chapters
          chapters.length * 4 + // content blocks + inline activities + legacy activities + images per chapter
          3; // quiz + vocab + progress
      onProgress?.call(completed, totalSteps);

      // Step 3: Per-chapter content
      for (final chapter in chapters) {
        // Content blocks
        if (chapter.useContentBlocks) {
          final blocksResult = await _contentBlockRepo.getContentBlocks(chapter.id);
          // Cache images from content blocks
          blocksResult.fold((_) {}, (blocks) async {
            for (final block in blocks) {
              if (block.imageUrl != null) {
                await _fileCacheService.getOrDownload(block.imageUrl!, bookId, 'image');
              }
              if (includeAudio && block.audioUrl != null) {
                await _fileCacheService.getOrDownload(block.audioUrl!, bookId, 'audio');
              }
            }
          });
        }
        completed++;
        onProgress?.call(completed, totalSteps);

        // Inline activities
        await _bookRepo.getInlineActivities(chapter.id);
        completed++;
        onProgress?.call(completed, totalSteps);

        // Legacy activities
        await _activityRepo.getActivitiesByChapter(chapter.id);
        completed++;
        onProgress?.call(completed, totalSteps);

        // Chapter images
        for (final imageUrl in chapter.imageUrls) {
          await _fileCacheService.getOrDownload(imageUrl, bookId, 'image');
        }
        // Chapter audio (optional)
        if (includeAudio && chapter.audioUrl != null) {
          await _fileCacheService.getOrDownload(chapter.audioUrl!, bookId, 'audio');
        }
        // Book cover
        bookResult.fold((_) {}, (book) async {
          if (book.coverUrl != null) {
            await _fileCacheService.getOrDownload(book.coverUrl!, bookId, 'image');
          }
        });
        completed++;
        onProgress?.call(completed, totalSteps);
      }

      // Step 4: Book quiz
      await _quizRepo.getQuizForBook(bookId);
      completed++;
      onProgress?.call(completed, totalSteps);

      // Step 5: Vocabulary words from inline activities
      // Collect all vocabulary_words IDs from all cached inline activities
      // and fetch them in batch via Supabase. The VocabularyRepository is NOT
      // wrapped, so we query Supabase directly and write to cached_vocabulary_words.
      try {
        final allVocabIds = <String>{};
        for (final chapter in chapters) {
          final activitiesResult = await _bookRepo.getInlineActivities(chapter.id);
          activitiesResult.fold((_) {}, (activities) {
            for (final activity in activities) {
              allVocabIds.addAll(activity.vocabularyWords);
            }
          });
        }
        if (allVocabIds.isNotEmpty) {
          // Batch fetch vocabulary words directly from Supabase
          final vocabRows = await Supabase.instance.client
              .from('vocabulary_words')
              .select()
              .inFilter('id', allVocabIds.toList());
          await _cacheStore.saveVocabularyWords(bookId, List<Map<String, dynamic>>.from(vocabRows));
          // Download vocabulary images/audio
          for (final row in vocabRows) {
            if (row['image_url'] != null) {
              await _fileCacheService.getOrDownload(row['image_url'] as String, bookId, 'image');
            }
            if (includeAudio && row['audio_url'] != null) {
              await _fileCacheService.getOrDownload(row['audio_url'] as String, bookId, 'audio');
            }
          }
        }
      } catch (e) {
        debugPrint('BookDownloadService: vocab download failed (non-fatal): $e');
      }
      completed++;
      onProgress?.call(completed, totalSteps);

      // Step 6: Reading progress + completed activity results
      try {
        await _bookRepo.getReadingProgress(userId: userId, bookId: bookId);
        // Completed inline activities
        for (final chapter in chapters) {
          await _bookRepo.getCompletedInlineActivities(userId: userId, chapterId: chapter.id);
        }
      } catch (e) {
        debugPrint('BookDownloadService: progress download failed (non-fatal): $e');
      }
      completed++;
      onProgress?.call(completed, totalSteps);

      await _cacheStore.setDownloadStatus(bookId, 'complete');
      return true;
    } catch (e) {
      debugPrint('BookDownloadService: download failed for $bookId: $e');
      await _cacheStore.setDownloadStatus(bookId, 'failed');
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
BookDownloadService bookDownloadService(BookDownloadServiceRef ref) {
  // Note: these repos are the REMOTE ones (not cached wrappers)
  // because the cached wrappers already handle caching on read
  return BookDownloadService(
    bookRepo: ref.watch(bookRepositoryProvider),
    contentBlockRepo: ref.watch(contentBlockRepositoryProvider),
    quizRepo: ref.watch(bookQuizRepositoryProvider),
    activityRepo: ref.watch(activityRepositoryProvider),
    cacheStore: ref.watch(bookCacheStoreProvider),
    fileCacheService: ref.watch(fileCacheServiceProvider),
  );
}
```

**Important:** Since the repositories are already cached wrappers (after Task 10), calling `getChapters()` etc. will automatically cache the results. The download service just needs to trigger the reads and handle file downloads.

- [ ] **Step 2: Run code generation + analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && dart analyze lib/core/services/book_download_service.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/book_download_service.dart lib/core/services/book_download_service.g.dart
git commit -m "feat: add BookDownloadService for background book downloading"
```

---

### Task 15: Create BookDownloadProvider

Riverpod state management for download progress and status.

**Files:**
- Create: `lib/presentation/providers/book_download_provider.dart`

- [ ] **Step 1: Write download provider**

```dart
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/book_cache_store.dart';
import '../../core/services/book_download_service.dart';
import '../../core/services/file_cache_service.dart';

part 'book_download_provider.g.dart';

/// Download status for a specific book
@riverpod
Future<String?> bookDownloadStatus(BookDownloadStatusRef ref, String bookId) async {
  final cacheStore = ref.watch(bookCacheStoreProvider);
  return cacheStore.getDownloadStatus(bookId);
}

/// Active download progress (bookId -> progress fraction 0.0-1.0)
@riverpod
class ActiveDownloads extends _$ActiveDownloads {
  @override
  Map<String, double> build() => {};

  void updateProgress(String bookId, double progress) {
    state = {...state, bookId: progress};
  }

  void removeDownload(String bookId) {
    state = Map.from(state)..remove(bookId);
  }
}

/// Start downloading a book
@riverpod
class BookDownloader extends _$BookDownloader {
  @override
  FutureOr<void> build() {}

  Future<bool> downloadBook(String bookId, {bool includeAudio = false}) async {
    final downloadService = ref.read(bookDownloadServiceProvider);
    final activeDownloads = ref.read(activeDownloadsProvider.notifier);

    activeDownloads.updateProgress(bookId, 0.0);

    final success = await downloadService.downloadBook(
      bookId,
      includeAudio: includeAudio,
      onProgress: (completed, total) {
        if (total > 0) {
          activeDownloads.updateProgress(bookId, completed / total);
        }
      },
    );

    activeDownloads.removeDownload(bookId);
    // Invalidate the download status provider to refresh UI
    ref.invalidate(bookDownloadStatusProvider(bookId));
    return success;
  }

  Future<void> removeDownload(String bookId) async {
    final cacheStore = ref.read(bookCacheStoreProvider);
    final fileCacheService = ref.read(fileCacheServiceProvider);

    // Delete files from filesystem
    await fileCacheService.deleteBookFiles(bookId);
    // Delete from cache database (CASCADE cleans all related rows)
    await cacheStore.deleteBook(bookId);
    // Refresh UI
    ref.invalidate(bookDownloadStatusProvider(bookId));
  }
}

/// All downloaded books with their info (for management screen)
@riverpod
Future<List<DownloadedBookInfo>> downloadedBooks(DownloadedBooksRef ref) async {
  final cacheStore = ref.watch(bookCacheStoreProvider);
  final rows = await cacheStore.getAllCachedBooks();

  final books = <DownloadedBookInfo>[];
  for (final row in rows) {
    if (row['download_status'] == 'complete') {
      final bookId = row['book_id'] as String;
      final cacheSize = await cacheStore.getBookCacheSize(bookId);
      books.add(DownloadedBookInfo(
        bookId: bookId,
        cachedAt: row['cached_at'] as String,
        includeAudio: (row['include_audio'] as int?) == 1,
        fileSizeBytes: cacheSize,
      ));
    }
  }
  return books;
}

class DownloadedBookInfo {
  const DownloadedBookInfo({
    required this.bookId,
    required this.cachedAt,
    required this.includeAudio,
    required this.fileSizeBytes,
  });

  final String bookId;
  final String cachedAt;
  final bool includeAudio;
  final int fileSizeBytes;

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
```

- [ ] **Step 2: Run code generation + analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && dart analyze lib/presentation/providers/book_download_provider.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/book_download_provider.dart lib/presentation/providers/book_download_provider.g.dart
git commit -m "feat: add book download providers for state management"
```

---

## Chunk 4: UI Integration

### Task 16: Add Download Button to BookDetailScreen

**Files:**
- Modify: `lib/presentation/screens/library/book_detail_screen.dart`
- Create: `lib/presentation/widgets/library/download_button.dart`

- [ ] **Step 1: Create DownloadButton widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/book_download_provider.dart';

class BookDownloadButton extends ConsumerWidget {
  const BookDownloadButton({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(bookDownloadStatusProvider(bookId));
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final activeProgress = activeDownloads[bookId];

    // Currently downloading — show progress
    if (activeProgress != null) {
      return CircularProgressIndicator(value: activeProgress, strokeWidth: 2);
    }

    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _buildDownloadIcon(context, ref),
      data: (status) {
        if (status == 'complete') {
          return const Icon(Icons.download_done, color: Colors.green);
        }
        return _buildDownloadIcon(context, ref);
      },
    );
  }

  Widget _buildDownloadIcon(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.download_for_offline_outlined),
      tooltip: 'Download for offline',
      onPressed: () => _showDownloadDialog(context, ref),
    );
  }

  Future<void> _showDownloadDialog(BuildContext context, WidgetRef ref) async {
    bool includeAudio = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Download Book'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Download this book for offline reading?'),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Include audio'),
                subtitle: const Text('Larger download size'),
                value: includeAudio,
                onChanged: (v) => setState(() => includeAudio = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Download')),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      ref.read(bookDownloaderProvider.notifier).downloadBook(bookId, includeAudio: includeAudio);
    }
  }
}
```

- [ ] **Step 2: Add DownloadButton to BookDetailScreen**

In `lib/presentation/screens/library/book_detail_screen.dart`, add `BookDownloadButton(bookId: bookId)` to the app bar actions or next to the book title area.

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/presentation/widgets/library/download_button.dart lib/presentation/screens/library/book_detail_screen.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/library/download_button.dart lib/presentation/screens/library/book_detail_screen.dart
git commit -m "feat: add download button to book detail screen"
```

---

### Task 17: Trigger Background Download on Start Reading

When user taps "Start Reading", download the rest of the book in background.

**Files:**
- Modify: `lib/presentation/screens/library/book_detail_screen.dart`

- [ ] **Step 1: Add background download trigger**

In the "Start Reading" / "Continue Reading" button's `onPressed` handler, after the navigation call, trigger background download:

```dart
// After: context.go(AppRoutes.readerPath(bookId, targetChapterId));
// Add:
ref.read(bookDownloaderProvider.notifier).downloadBook(bookId);
```

This is fire-and-forget — user navigates to reader while download happens in background.

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/presentation/screens/library/book_detail_screen.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/library/book_detail_screen.dart
git commit -m "feat: trigger background book download on Start Reading"
```

---

### Task 18: Create OfflineSyncService

Syncs dirty records when connectivity is restored.

**Files:**
- Create: `lib/core/services/offline_sync_service.dart`

- [ ] **Step 1: Write OfflineSyncService**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/book/reading_progress_model.dart';
import '../../domain/repositories/book_repository.dart';
import '../network/network_info.dart';
import 'book_cache_store.dart';

part 'offline_sync_service.g.dart';

class OfflineSyncService {
  OfflineSyncService({
    required BookCacheStore cacheStore,
    required BookRepository bookRepo,
    required ActivityRepository activityRepo,
    required BookQuizRepository quizRepo,
    required EdgeFunctionService edgeFunctionService,
    required NetworkInfo networkInfo,
  })  : _cacheStore = cacheStore,
        _bookRepo = bookRepo,
        _activityRepo = activityRepo,
        _quizRepo = quizRepo,
        _edgeFunctionService = edgeFunctionService,
        _networkInfo = networkInfo;

  final BookCacheStore _cacheStore;
  final BookRepository _bookRepo;
  final ActivityRepository _activityRepo;
  final BookQuizRepository _quizRepo;
  final EdgeFunctionService _edgeFunctionService;
  final NetworkInfo _networkInfo;

  bool _isSyncing = false;

  /// Start listening for connectivity changes and sync when online.
  void startListening() {
    _networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected) syncAll();
    });
  }

  /// Sync all dirty records to remote.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (!await _networkInfo.isConnected) return;

    _isSyncing = true;
    try {
      await _syncReadingProgress();
      await _syncInlineActivityResults();
      await _syncActivityResults();
      await _syncQuizResults();
      await _syncPendingActions();
      // Re-fetch reading progress from server (authoritative for is_completed)
      await _refreshReadingProgressFromServer();
    } catch (e) {
      debugPrint('OfflineSyncService: sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncReadingProgress() async {
    final dirtyRows = await _cacheStore.getDirtyReadingProgress();
    for (final row in dirtyRows) {
      try {
        final progressJson = jsonDecode(row['progress_json'] as String) as Map<String, dynamic>;
        final progress = ReadingProgressModel.fromJson(progressJson).toEntity();
        await _bookRepo.updateReadingProgress(progress);
        await _cacheStore.clearDirtyFlag('cached_reading_progress', 'id', row['id'] as String);
      } catch (e) {
        debugPrint('OfflineSyncService: failed to sync reading progress: $e');
      }
    }
  }

  Future<void> _syncInlineActivityResults() async {
    final dirtyRows = await _cacheStore.getDirtyInlineActivityResults();
    for (final row in dirtyRows) {
      try {
        await _bookRepo.saveInlineActivityResult(
          userId: row['user_id'] as String,
          activityId: row['inline_activity_id'] as String,
          isCorrect: (row['is_correct'] as int) == 1,
          xpEarned: row['xp_earned'] as int,
        );
        await _cacheStore.clearDirtyFlag('cached_inline_activity_results', 'inline_activity_id', row['inline_activity_id'] as String);
      } catch (e) {
        debugPrint('OfflineSyncService: failed to sync inline activity result: $e');
      }
    }
  }

  Future<void> _syncActivityResults() async {
    final dirtyRows = await _cacheStore.getDirtyActivityResults();
    for (final row in dirtyRows) {
      try {
        final resultJson = jsonDecode(row['result_json'] as String) as Map<String, dynamic>;
        final result = ActivityResultModel.fromJson(resultJson).toEntity();
        await _activityRepo.submitActivityResult(result);
        await _cacheStore.clearDirtyFlag('cached_activity_results', 'id', row['id'] as String);
      } catch (e) {
        debugPrint('OfflineSyncService: failed to sync activity result: $e');
      }
    }
  }

  Future<void> _syncQuizResults() async {
    final dirtyRows = await _cacheStore.getDirtyQuizResults();
    for (final row in dirtyRows) {
      try {
        final resultJson = jsonDecode(row['result_json'] as String) as Map<String, dynamic>;
        final result = BookQuizResultModel.fromJson(resultJson).toEntity();
        await _quizRepo.submitQuizResult(result);
        await _cacheStore.clearDirtyFlag('cached_book_quiz_results', 'id', row['id'] as String);
      } catch (e) {
        debugPrint('OfflineSyncService: failed to sync quiz result: $e');
      }
    }
  }

  Future<void> _syncPendingActions() async {
    final actions = await _cacheStore.getPendingActions();
    for (final action in actions) {
      try {
        final type = action['action_type'] as String;
        final payload = jsonDecode(action['payload_json'] as String) as Map<String, dynamic>;

        switch (type) {
          case 'award_xp':
            await _edgeFunctionService.awardXp(
              userId: payload['userId'] as String,
              amount: payload['xp'] as int? ?? 0,
              reason: 'chapter_completion',
            );
          case 'log_daily_read':
            // Insert into daily_chapter_reads via Supabase
            await Supabase.instance.client.from('daily_chapter_reads').upsert({
              'user_id': payload['userId'],
              'chapter_id': payload['chapterId'],
              'read_date': payload['readDate'] ?? DateTime.now().toIso8601String().split('T')[0],
            });
          case 'check_assignment':
            // Assignment check is handled by the reading progress sync
            // (server-side triggers recalculate assignment progress)
            break;
        }

        await _cacheStore.deletePendingAction(action['id'] as int);
      } catch (e) {
        debugPrint('OfflineSyncService: failed to process pending action: $e');
        // Don't delete — retry on next sync
      }
    }
  }

  Future<void> _refreshReadingProgressFromServer() async {
    // Re-fetch dirty books' reading progress from server (authoritative for is_completed)
    final dirtyRows = await _cacheStore.getDirtyReadingProgress();
    for (final row in dirtyRows) {
      try {
        final result = await _bookRepo.getReadingProgress(
          userId: row['user_id'] as String,
          bookId: row['book_id'] as String,
        );
        result.fold((_) {}, (serverProgress) {
          _cacheStore.saveReadingProgress(serverProgress); // Overwrite with server truth
        });
      } catch (_) {}
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
  return service;
}
```

**Important:** The `bookRepositoryProvider` at this point returns a `CachedBookRepository`. For sync, we need to call the remote directly. During implementation, verify whether the write-through methods in `CachedBookRepository` correctly forward to remote when online (they should, per the cache-aside pattern). If so, calling the cached wrapper's methods during sync is fine — they'll forward to remote.

- [ ] **Step 2: Initialize sync service in app startup**

In `main.dart` or the app's root widget, ensure `offlineSyncServiceProvider` is read at startup so it starts listening:

```dart
// In app initialization:
ref.read(offlineSyncServiceProvider);
```

- [ ] **Step 3: Run code generation + analyze**

Run: `dart run build_runner build --delete-conflicting-outputs && dart analyze lib/core/services/offline_sync_service.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/core/services/offline_sync_service.dart lib/core/services/offline_sync_service.g.dart
git commit -m "feat: add OfflineSyncService for dirty record synchronization"
```

---

### Task 19: Create Downloaded Books Management Screen

**Files:**
- Create: `lib/presentation/screens/profile/downloaded_books_screen.dart`
- Modify: `lib/presentation/screens/profile/profile_screen.dart`

- [ ] **Step 1: Write DownloadedBooksScreen**

Create `lib/presentation/screens/profile/downloaded_books_screen.dart`:

A simple screen showing all downloaded books with size info and remove buttons. Uses `downloadedBooksProvider` and `bookByIdProvider` for book metadata.

Key elements:
- `ListView` of downloaded books
- Per-book: cover image, title, chapter count, file size, "Remove Download" button
- Total storage used at top
- "Remove All Downloads" button at bottom
- Empty state when no books downloaded

- [ ] **Step 2: Add navigation link in ProfileScreen**

In `lib/presentation/screens/profile/profile_screen.dart`, add a "Downloaded Books" button/tile after the achievements section (after line ~166):

```dart
ListTile(
  leading: const Icon(Icons.download_done),
  title: const Text('Downloaded Books'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/profile/downloads'),
),
```

- [ ] **Step 3: Add route in router.dart**

In `lib/app/router.dart`, add a route for the downloads screen under the profile section.

- [ ] **Step 4: Run analyze**

Run: `dart analyze lib/presentation/screens/profile/downloaded_books_screen.dart lib/presentation/screens/profile/profile_screen.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/profile/downloaded_books_screen.dart lib/presentation/screens/profile/profile_screen.dart lib/app/router.dart
git commit -m "feat: add Downloaded Books management screen accessible from profile"
```

---

## Chunk 5: Testing + Final Integration

### Task 20: Unit Tests for BookCacheStore

**Files:**
- Create: `test/unit/core/services/book_cache_store_test.dart`

- [ ] **Step 1: Write tests for core cache operations**

Test key operations using sqflite's in-memory database (`sqflite_common_ffi` for testing):

```dart
// Key test cases:
// - saveBook + getBook round-trip
// - saveChapters + getChapters returns ordered list
// - saveContentBlocks + getContentBlocks round-trip
// - deleteBook cascades to all related tables
// - getDownloadStatus / setDownloadStatus
// - getDirtyReadingProgress returns only dirty records
// - getBookCacheSize returns correct sum
// - queuePendingAction + getPendingActions + deletePendingAction
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/unit/core/services/book_cache_store_test.dart`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add test/unit/core/services/book_cache_store_test.dart
git commit -m "test: add unit tests for BookCacheStore"
```

---

### Task 21: Unit Tests for CachedBookRepository

**Files:**
- Create: `test/unit/data/repositories/cached_book_repository_test.dart`

- [ ] **Step 1: Write tests**

Test the three method types using mocks:

```dart
// Key test cases:
// Cache-aside:
// - Returns cached data when available (no remote call)
// - Falls back to remote when cache empty
// - Writes remote result to cache on success

// Write-through:
// - Online: writes to both remote and cache
// - Offline: writes to cache with dirty flag, returns success

// Pass-through:
// - Always delegates to remote
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/unit/data/repositories/cached_book_repository_test.dart`

- [ ] **Step 3: Commit**

```bash
git add test/unit/data/repositories/cached_book_repository_test.dart
git commit -m "test: add unit tests for CachedBookRepository"
```

---

### Task 22: Full Integration Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full analyze**

Run: `dart analyze lib/`
Expected: No errors

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All pass

- [ ] **Step 3: Manual verification checklist**

Verify on device/emulator:
1. Open a book → "Start Reading" → chapter 1 loads
2. Navigate to chapter 2 → should load faster (or instantly if download completed)
3. Tap download button on book detail → dialog appears → download starts
4. Progress indicator shows during download
5. After download, "downloaded" badge visible
6. Kill app → restart → same book chapter loads from cache (no spinner)
7. Enable airplane mode → navigate between cached chapters → works offline
8. Disable airplane mode → changes sync to server
9. Profile → "Downloaded Books" → shows list with sizes
10. Remove a download → book removed from list, reading still works online

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete offline book cache system integration"
```
