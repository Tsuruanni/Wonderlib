import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

part 'book_cache_database.g.dart';

/// sqflite database for offline book caching.
///
/// Holds all 13 cache tables. Use [BookCacheDatabase.database] to obtain
/// the lazily-initialised [Database] instance.
///
/// Tables that store user progress ([cached_reading_progress],
/// [cached_inline_activity_results], [cached_activity_results]) intentionally
/// omit foreign keys so that progress survives book-cache deletions.
class BookCacheDatabase {
  Database? _db;

  /// Returns the lazily-initialised database instance.
  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'book_cache.db');

    return openDatabase(
      dbPath,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  /// Enable foreign key enforcement.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create all 13 cache tables in a single batch.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ------------------------------------------------------------------ books
    batch.execute('''
      CREATE TABLE cached_books (
        book_id           TEXT PRIMARY KEY,
        book_json         TEXT NOT NULL,
        updated_at        TEXT NOT NULL,
        cached_at         TEXT NOT NULL,
        include_audio     INTEGER NOT NULL DEFAULT 0,
        download_status   TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    // --------------------------------------------------------------- chapters
    batch.execute('''
      CREATE TABLE cached_chapters (
        chapter_id          TEXT PRIMARY KEY,
        book_id             TEXT NOT NULL,
        chapter_json        TEXT NOT NULL,
        updated_at          TEXT NOT NULL,
        order_index         INTEGER NOT NULL,
        use_content_blocks  INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES cached_books (book_id) ON DELETE CASCADE
      )
    ''');

    // --------------------------------------------------------- content blocks
    batch.execute('''
      CREATE TABLE cached_content_blocks (
        id                  TEXT PRIMARY KEY,
        chapter_id          TEXT NOT NULL,
        content_block_json  TEXT NOT NULL,
        order_index         INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES cached_chapters (chapter_id) ON DELETE CASCADE
      )
    ''');

    // --------------------------------------------------- inline activities
    batch.execute('''
      CREATE TABLE cached_inline_activities (
        id                      TEXT PRIMARY KEY,
        chapter_id              TEXT NOT NULL,
        activity_json           TEXT NOT NULL,
        after_paragraph_index   INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES cached_chapters (chapter_id) ON DELETE CASCADE
      )
    ''');

    // ----------------------------------------------------------- activities
    batch.execute('''
      CREATE TABLE cached_activities (
        id            TEXT PRIMARY KEY,
        chapter_id    TEXT NOT NULL,
        activity_json TEXT NOT NULL,
        order_index   INTEGER NOT NULL,
        FOREIGN KEY (chapter_id) REFERENCES cached_chapters (chapter_id) ON DELETE CASCADE
      )
    ''');

    // ------------------------------------------------------- book quizzes
    batch.execute('''
      CREATE TABLE cached_book_quizzes (
        quiz_id   TEXT PRIMARY KEY,
        book_id   TEXT NOT NULL,
        quiz_json TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books (book_id) ON DELETE CASCADE
      )
    ''');

    // ------------------------------------------------- book quiz results
    batch.execute('''
      CREATE TABLE cached_book_quiz_results (
        id          TEXT PRIMARY KEY,
        quiz_id     TEXT NOT NULL,
        book_id     TEXT NOT NULL,
        user_id     TEXT NOT NULL,
        result_json TEXT NOT NULL,
        is_dirty    INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES cached_books (book_id) ON DELETE CASCADE
      )
    ''');

    // ------------------------------------------------- vocabulary words
    batch.execute('''
      CREATE TABLE cached_vocabulary_words (
        word_id   TEXT PRIMARY KEY,
        book_id   TEXT NOT NULL,
        word_json TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books (book_id) ON DELETE CASCADE
      )
    ''');

    // -------------------------------------------- reading progress (no FK)
    // Composite logical key: user_id + book_id stored in the 'id' column.
    // No FK — progress must survive book-cache deletion.
    batch.execute('''
      CREATE TABLE cached_reading_progress (
        id            TEXT PRIMARY KEY,
        book_id       TEXT NOT NULL,
        user_id       TEXT NOT NULL,
        progress_json TEXT NOT NULL,
        is_dirty      INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // --------------------------------------- inline activity results (no FK)
    // No FK — results must survive book-cache deletion.
    batch.execute('''
      CREATE TABLE cached_inline_activity_results (
        inline_activity_id  TEXT PRIMARY KEY,
        book_id             TEXT NOT NULL,
        user_id             TEXT NOT NULL,
        is_correct          INTEGER NOT NULL,
        xp_earned           INTEGER NOT NULL,
        answered_at         TEXT NOT NULL,
        is_dirty            INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // -------------------------------------------- activity results (no FK)
    // No FK — results must survive book-cache deletion.
    batch.execute('''
      CREATE TABLE cached_activity_results (
        id          TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL,
        book_id     TEXT NOT NULL,
        user_id     TEXT NOT NULL,
        result_json TEXT NOT NULL,
        is_dirty    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // --------------------------------------------------------------- files
    batch.execute('''
      CREATE TABLE cached_files (
        url         TEXT PRIMARY KEY,
        book_id     TEXT NOT NULL,
        local_path  TEXT NOT NULL,
        file_type   TEXT NOT NULL,
        file_size   INTEGER NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books (book_id) ON DELETE CASCADE
      )
    ''');

    // ----------------------------------------- offline pending actions
    batch.execute('''
      CREATE TABLE offline_pending_actions (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type   TEXT NOT NULL,
        payload_json  TEXT NOT NULL,
        book_id       TEXT NOT NULL,
        created_at    TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES cached_books (book_id) ON DELETE CASCADE
      )
    ''');

    await batch.commit(noResult: true);
  }

  /// Delete the on-disk database file. Useful for testing and cache resets.
  Future<void> deleteDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'book_cache.db');
    await databaseFactory.deleteDatabase(dbPath);
  }
}

@Riverpod(keepAlive: true)
BookCacheDatabase bookCacheDatabase(BookCacheDatabaseRef ref) {
  return BookCacheDatabase();
}
