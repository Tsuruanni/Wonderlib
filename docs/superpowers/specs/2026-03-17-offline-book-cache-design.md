# Offline Book Cache System — Design Spec

**Date:** 2026-03-17
**Status:** Approved
**Scope:** Owlio Mobile App (`/Users/wonderelt/Desktop/Owlio`)

---

## Problem

When a user opens a book and navigates between chapters, each chapter's content blocks, inline activities, and related data are fetched individually from Supabase. This causes:

- Loading spinners on every chapter transition
- No offline reading capability
- Redundant network calls (chapter fetched both in batch and individually, `use_content_blocks` queried separately)
- Poor UX on slow connections

## Goals

1. **Instant chapter transitions** — all book content pre-loaded after "Start Reading"
2. **Offline reading** — downloaded books readable without internet
3. **Explicit download** — "Download" button for intentional offline preparation
4. **Optional audio download** — text content default, audio opt-in
5. **Cache freshness** — `updated_at` comparison to detect stale content
6. **Downloaded books management** — Settings screen to view/remove downloads
7. **Offline progress sync** — reading progress and activity results saved locally, synced when online

## Non-Goals

- Offline vocabulary learning sessions (separate feature)
- Offline leaderboard or social features
- Streaming/partial chapter downloads
- Word list caching (accessed from vocabulary section, not reader)

---

## Approach: sqflite Cache Layer with Repository Wrapper

sqflite is already a project dependency. No new packages needed for the core cache. The system uses the **cache-aside pattern** implemented as repository wrappers that sit between the existing domain interfaces and Supabase implementations.

### Why This Approach

- **Zero changes** to UseCases, Entities, Models, Provider chains
- **Only repository implementation swap** in `repository_providers.dart`
- Existing `SupabaseBookRepository` stays untouched — wrapped, not modified
- sqflite provides structured queries for partial updates and size tracking
- Audio files stored on filesystem, metadata in sqflite (hybrid)

---

## Data Types to Cache

| Data Type | Table(s) | Scope | URL Fields to Cache | Priority |
|---|---|---|---|---|
| Book metadata | `books` | per-book | `cover_url` | Required |
| Chapters | `chapters` | per-book (1:N) | `audio_url`, `image_urls[]` | Required |
| Content Blocks | `content_blocks` | per-chapter (1:N) | `audio_url`, `image_url` | Required |
| Inline Activities | `inline_activities` | per-chapter (1:N) | none | Required |
| Legacy Activities | `activities` | per-chapter (1:N) | `questions[].image_url` | Required |
| Book Quiz | `book_quizzes` + `book_quiz_questions` | per-book (0-1) | none | Required |
| Vocabulary Words | `vocabulary_words` | referenced by inline activities | `audio_url`, `image_url` | Required |
| Reading Progress | `reading_progress` | per-user per-book | none | Required |
| Activity Results | `inline_activity_results` | per-user per-activity | none | Required |

**Not cached:**
- Word lists (`word_lists`) — accessed from vocabulary section, not reader
- User XP/badges — requires server-side validation

---

## Cache Database Schema

File: `book_cache.db` in `getApplicationDocumentsDirectory()`

```sql
CREATE TABLE cached_books (
  book_id TEXT PRIMARY KEY,
  book_json TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  cached_at TEXT NOT NULL,
  include_audio INTEGER DEFAULT 0,
  download_status TEXT DEFAULT 'pending'  -- pending | downloading | complete | failed
);

CREATE TABLE cached_chapters (
  chapter_id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  chapter_json TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  order_index INTEGER NOT NULL,
  use_content_blocks INTEGER DEFAULT 0,
  FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
);

CREATE TABLE cached_content_blocks (
  id TEXT PRIMARY KEY,
  chapter_id TEXT NOT NULL,
  content_block_json TEXT NOT NULL,
  order_index INTEGER NOT NULL,
  FOREIGN KEY (chapter_id) REFERENCES cached_chapters(chapter_id) ON DELETE CASCADE
);

CREATE TABLE cached_inline_activities (
  id TEXT PRIMARY KEY,
  chapter_id TEXT NOT NULL,
  activity_json TEXT NOT NULL,
  after_paragraph_index INTEGER NOT NULL,
  FOREIGN KEY (chapter_id) REFERENCES cached_chapters(chapter_id) ON DELETE CASCADE
);

CREATE TABLE cached_activities (
  id TEXT PRIMARY KEY,
  chapter_id TEXT NOT NULL,
  activity_json TEXT NOT NULL,
  order_index INTEGER NOT NULL,
  FOREIGN KEY (chapter_id) REFERENCES cached_chapters(chapter_id) ON DELETE CASCADE
);

CREATE TABLE cached_book_quizzes (
  quiz_id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  quiz_json TEXT NOT NULL,
  FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
);

CREATE TABLE cached_vocabulary_words (
  word_id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  word_json TEXT NOT NULL,
  FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
);

CREATE TABLE cached_reading_progress (
  book_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  progress_json TEXT NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

CREATE TABLE cached_activity_results (
  inline_activity_id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

CREATE TABLE cached_files (
  url TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  local_path TEXT NOT NULL,
  file_type TEXT NOT NULL,  -- 'image' | 'audio'
  file_size INTEGER NOT NULL,
  FOREIGN KEY (book_id) REFERENCES cached_books(book_id) ON DELETE CASCADE
);
```

**Design decisions:**
- JSON blob storage for model data — avoids cache DB migrations when models change
- `ON DELETE CASCADE` — removing a book cleans all related data
- `url` as PK for `cached_files` — deduplicates identical images/audio across chapters
- `is_dirty` flag — marks offline changes needing sync
- `use_content_blocks` on chapter row — eliminates the separate boolean query
- `download_status` — tracks partial downloads for resume capability

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                      │
│  Screen → Provider → UseCase (NO CHANGES)                │
└─────────────────────┬────────────────────────────────────┘
                      │
┌─────────────────────▼────────────────────────────────────┐
│                    DOMAIN LAYER                           │
│  Repository Interface (NO CHANGES)                       │
└─────────────────────┬────────────────────────────────────┘
                      │
┌─────────────────────▼────────────────────────────────────┐
│                     DATA LAYER                            │
│                                                           │
│  ┌─────────────────────────────────────────────────┐     │
│  │       CachedBookRepository (NEW)                │     │
│  │  implements BookRepository                       │     │
│  │                                                  │     │
│  │  1. Cache hit? → return local data               │     │
│  │  2. Online? → fetch remote + write cache         │     │
│  │  3. Offline + no cache? → return Failure         │     │
│  └──────────┬──────────────────┬────────────────────┘     │
│             │                  │                          │
│  ┌──────────▼──────┐  ┌───────▼──────────────┐          │
│  │ BookCacheStore  │  │ SupabaseBookRepo     │          │
│  │ (sqflite)       │  │ (existing, untouched)│          │
│  └─────────────────┘  └──────────────────────┘          │
│                                                           │
│  Same pattern applied to:                                │
│  - CachedContentBlockRepository                          │
│  - CachedBookQuizRepository                              │
│  - CachedActivityRepository                              │
└──────────────────────────────────────────────────────────┘
```

---

## Download Flow

### Implicit (Start Reading)

1. User taps "Start Reading"
2. Chapter 1 loaded immediately (cache or network)
3. `BookDownloadService` starts in background:
   - All remaining chapters
   - All content blocks for all chapters
   - All inline activities for all chapters
   - All legacy activities for all chapters
   - Book quiz + questions
   - Vocabulary words referenced by inline activities
   - All images (cover, chapter images, content block images, activity question images)
4. User reads chapter 1 while rest downloads
5. Chapter transitions become instant as data arrives in cache

### Explicit (Download Button)

1. User taps download icon on `BookDetailScreen`
2. Dialog shows:
   - Book content size estimate
   - "Include audio" checkbox with audio size estimate
3. `BookDownloadService` starts, same as above + audio if selected
4. Progress bar shown on BookDetailScreen
5. Book marked with "Downloaded" badge in library

### Download Service Orchestration

```
BookDownloadService.downloadBook(bookId, includeAudio):
  1. Set download_status = 'downloading'
  2. Fetch + cache book metadata
  3. Fetch + cache all chapters (single batch query)
  4. For each chapter (parallel):
     a. Fetch + cache content blocks
     b. Fetch + cache inline activities
     c. Fetch + cache legacy activities
     d. Download + cache images from content blocks
     e. Download + cache images from chapter.image_urls
     f. (if includeAudio) Download + cache audio files
  5. Fetch + cache book quiz (if exists)
  6. Collect all vocabulary word IDs from inline activities
  7. Fetch + cache vocabulary words (batch)
  8. Download + cache vocabulary word images/audio
  9. Fetch + cache reading progress
  10. Fetch + cache completed activity results
  11. Set download_status = 'complete'

  On any failure: set download_status = 'failed', partial cache retained
```

---

## Cache-Aside Read Pattern

Every repository method follows this pattern:

```dart
Future<Either<Failure, T>> getData(String id) async {
  // 1. Check local cache
  final cached = await _cacheStore.get(id);
  if (cached != null) {
    // 2. Background freshness check (fire-and-forget, online only)
    _checkFreshnessInBackground(id);
    return Right(cached);
  }

  // 3. No cache — fetch from network
  final result = await _remoteRepo.getData(id);

  // 4. On success, write to cache
  result.fold(
    (failure) => null,
    (data) => _cacheStore.save(id, data),
  );

  return result;
}
```

### Freshness Check

```dart
Future<void> _checkFreshnessInBackground(String bookId) async {
  if (!await _connectivity.isOnline) return;

  final remoteTimestamps = await _remoteRepo.getChapterTimestamps(bookId);
  final localTimestamps = await _cacheStore.getChapterTimestamps(bookId);

  for (final remote in remoteTimestamps) {
    if (remote.updatedAt != localTimestamps[remote.id]) {
      // Fetch and update only changed chapters + their content
      final fresh = await _remoteRepo.getChapterById(remote.id);
      fresh.fold((_) => null, (c) => _cacheStore.saveChapter(bookId, c));
      // Also refresh content blocks, activities for changed chapter
    }
  }
}
```

---

## File Cache (Images + Audio)

```dart
class FileCacheService {
  // Base path: getApplicationDocumentsDirectory()/book_cache/

  Future<String> getOrDownload(String remoteUrl, String bookId, String fileType) async {
    // 1. Check cached_files table
    final localPath = await _cacheStore.getLocalPath(remoteUrl);
    if (localPath != null && File(localPath).existsSync()) return localPath;

    // 2. Download file
    final bytes = await _httpClient.getBytes(remoteUrl);
    final path = '$_baseDir/$bookId/${md5(remoteUrl)}${extension(remoteUrl)}';
    await File(path).writeAsBytes(bytes);

    // 3. Record in DB
    await _cacheStore.saveFile(
      url: remoteUrl,
      bookId: bookId,
      localPath: path,
      fileType: fileType,
      fileSize: bytes.length,
    );

    return path;
  }
}
```

Image widgets use a `CachedBookImage` wrapper that checks local file first, falls back to network.

---

## Offline Progress Sync

### Writing Progress Offline

When offline, progress writes go to local cache with `is_dirty = 1`:
- `cached_reading_progress` — chapter position, reading time, completion
- `cached_activity_results` — inline activity completions

XP awards and badge checks are queued (not executed offline).

### Syncing on Reconnect

`OfflineSyncService` listens to connectivity changes:

```
Online detected:
  1. Find all cached_reading_progress WHERE is_dirty = 1
  2. For each: upsert to Supabase reading_progress
  3. Find all cached_activity_results WHERE is_dirty = 1
  4. For each: submit to Supabase inline_activity_results
  5. Process queued XP awards
  6. Set is_dirty = 0 on success
```

---

## Quick Wins (Independent of Cache System)

These eliminate redundant network calls regardless of caching:

| Issue | Fix | Impact |
|---|---|---|
| `chapterByIdProvider` re-fetches already-loaded chapter | Filter from `chaptersProvider` result | -1 network call per chapter open |
| `use_content_blocks` separate query | Include in Chapter entity/model | -1 network call per chapter open |
| `markChapterComplete` re-fetches all chapters | Read from Riverpod cache | -1 network call per chapter completion |

---

## New Files

```
lib/core/services/
  book_cache_database.dart        — sqflite DB initialization + schema
  book_cache_store.dart           — CRUD operations on all cache tables
  book_download_service.dart      — Orchestrates full book download
  file_cache_service.dart         — Image/audio file download + local storage
  offline_sync_service.dart       — Dirty record sync on reconnect
  connectivity_service.dart       — Online/offline state stream

lib/data/repositories/cached/
  cached_book_repository.dart     — Wraps SupabaseBookRepository
  cached_content_block_repository.dart
  cached_book_quiz_repository.dart
  cached_activity_repository.dart

lib/presentation/providers/
  book_download_provider.dart     — Download state, progress, management
  connectivity_provider.dart      — Online/offline Riverpod state

lib/presentation/screens/settings/
  downloaded_books_screen.dart    — View/remove downloaded books

lib/presentation/widgets/common/
  cached_book_image.dart          — Cache-aware image widget

lib/presentation/widgets/library/
  download_button.dart            — Download icon/progress on BookDetailScreen
```

## Modified Files

| File | Change |
|---|---|
| `repository_providers.dart` | Swap Supabase repos with Cached wrappers |
| `book_detail_screen.dart` | Add download button, show download status badge |
| `reader_screen.dart` | Remove redundant `chapterByIdProvider`, use chapters list |
| `reader_body.dart` | Remove separate `use_content_blocks` query |
| `book_provider.dart` | Fix `chapterByIdProvider` to filter from batch |
| `settings_screen.dart` | Add "Downloaded Books" navigation link |
| `chapter_model.dart` | Add `useContentBlocks` field |
| `chapter.dart` (entity) | Add `useContentBlocks` field |

## Unchanged Layers

- All 117 UseCases
- All 21 Entities (except `Chapter` gains one field)
- All 38 Models (except `ChapterModel` gains one field)
- All domain repository interfaces
- All provider → usecase chains
- All screen → provider chains

---

## Downloaded Books Management Screen

Accessible from Settings. Shows:
- List of downloaded books with cover, title, chapter count
- Per-book storage size (text + images + audio separately)
- Total storage used
- "Last read" date
- "Remove Download" per book (deletes cache + files)
- "Remove All Downloads" bulk action

Removing a download:
1. Delete from `cached_books` (CASCADE removes all related rows)
2. Delete files from filesystem (`book_cache/{bookId}/`)
3. Reading progress is NOT deleted (stays on server)
