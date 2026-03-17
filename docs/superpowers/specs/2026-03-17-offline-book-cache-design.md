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
6. **Downloaded books management** — screen to view/remove downloads (accessible from profile)
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

- **Minimal changes** to UseCases, Entities, Models, Provider chains
- **Only repository implementation swap** in `repository_providers.dart`
- Existing Supabase repositories stay untouched — wrapped, not modified
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
| Inline Activity Results | `inline_activity_results` | per-user per-activity | none | Required |
| Legacy Activity Results | `activity_results` | per-user per-activity | none | Required |

**Not cached:**
- Word lists (`word_lists`) — accessed from vocabulary section, not reader
- User XP/badges — requires server-side validation
- Teacher/aggregate queries (`getRecommendedBooks`, `getContinueReading`, `getCompletedBookIds`, `hasReadToday`, `getCorrectAnswersTodayCount`, `getWordsReadTodayCount`, `getUnitBooks`) — these are user-scoped aggregate queries that always go to remote

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
  id TEXT PRIMARY KEY,             -- composite: {user_id}_{book_id}
  book_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  progress_json TEXT NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

CREATE TABLE cached_inline_activity_results (
  inline_activity_id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  is_correct INTEGER NOT NULL,
  xp_earned INTEGER NOT NULL,
  answered_at TEXT NOT NULL,
  is_dirty INTEGER DEFAULT 0
);

CREATE TABLE cached_activity_results (
  id TEXT PRIMARY KEY,             -- result UUID
  activity_id TEXT NOT NULL,
  book_id TEXT NOT NULL,
  result_json TEXT NOT NULL,       -- full ActivityResult serialized
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
- `cached_reading_progress.id` is composite `{user_id}_{book_id}` — supports multi-user on same device
- `cached_inline_activity_results` stores full result data (`is_correct`, `xp_earned`, `answered_at`) — needed for sync replay
- `cached_activity_results` stores full `result_json` — needed for sync replay
- **Freshness granularity:** `updated_at` is tracked at book and chapter level only. Content block, activity, and vocabulary changes are detected via their parent chapter's `updated_at`. This is acceptable because admin edits to content blocks/activities will bump the chapter's `updated_at` timestamp. If this assumption proves wrong, per-table `updated_at` can be added later.

---

## Architecture

### Repository Wrapper Pattern

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
│  │     CachedBookRepository (NEW)                  │     │
│  │  implements BookRepository                       │     │
│  │  delegates to SupabaseBookRepository             │     │
│  │  + BookCacheStore for local reads/writes         │     │
│  └──────────┬──────────────────┬────────────────────┘     │
│             │                  │                          │
│  ┌──────────▼──────┐  ┌───────▼──────────────┐          │
│  │ BookCacheStore  │  │ SupabaseBookRepo     │          │
│  │ (sqflite)       │  │ (existing, untouched)│          │
│  └─────────────────┘  └──────────────────────┘          │
│                                                           │
│  Same pattern for:                                       │
│  - CachedContentBlockRepository (wraps Supabase impl)    │
│  - CachedBookQuizRepository (wraps Supabase impl)        │
│  - CachedActivityRepository (wraps Supabase impl)        │
└──────────────────────────────────────────────────────────┘
```

### BookRepository Method Classification (21 methods)

The `BookRepository` interface has 21 methods. Each gets one of three treatments:

**Cache-aside (read from cache first, fall back to remote):**

| Method | Cache table | Notes |
|---|---|---|
| `getBookById()` | `cached_books` | |
| `getChapters()` | `cached_chapters` | Batch by bookId |
| `getChapterById()` | `cached_chapters` | Single row lookup |
| `getReadingProgress()` | `cached_reading_progress` | Per-user per-book |
| `getInlineActivities()` | `cached_inline_activities` | By chapterId |
| `getCompletedInlineActivities()` | `cached_inline_activity_results` | By user+chapter |

**Write-through (write to cache + remote if online, cache-only if offline):**

| Method | Offline behavior | Notes |
|---|---|---|
| `updateReadingProgress()` | Write to cache with `is_dirty=1` | Sync on reconnect |
| `updateCurrentChapter()` | Write to cache with `is_dirty=1` | Sync on reconnect |
| `saveInlineActivityResult()` | Write to cache with `is_dirty=1`, optimistically return `true` | Duplicate check deferred to sync |
| `markChapterComplete()` | See "Offline Chapter Completion" section below | Complex — needs special handling |

**Pass-through (always go to remote, no caching):**

| Method | Reason |
|---|---|
| `getBooks()` | Library listing with filters — not book-specific |
| `searchBooks()` | Dynamic search query |
| `getRecommendedBooks()` | Server-side recommendation logic |
| `getContinueReading()` | Cross-book aggregate |
| `getUserReadingHistory()` | Cross-book aggregate |
| `getCompletedBookIds()` | Cross-book aggregate |
| `hasReadToday()` | Time-sensitive aggregate |
| `getCorrectAnswersTodayCount()` | Time-sensitive aggregate |
| `getWordsReadTodayCount()` | Time-sensitive aggregate |
| `getUnitBooks()` | School/class scoped — not cacheable per-book |

### ContentBlockRepository Method Classification (3 methods)

| Method | Treatment | Notes |
|---|---|---|
| `getContentBlocks()` | Cache-aside | By chapterId |
| `getContentBlockById()` | Cache-aside | Single row |
| `chapterUsesContentBlocks()` | **Eliminated** | Read from `Chapter.useContentBlocks` field instead |

### BookQuizRepository Method Classification (6 methods)

| Method | Treatment | Notes |
|---|---|---|
| `getQuizForBook()` | Cache-aside | Per-book |
| `bookHasQuiz()` | Cache-aside (derived) | Check if `cached_book_quizzes` has row for bookId |
| `submitQuizResult()` | Write-through | Cache + remote if online, cache-only if offline |
| `getBestResult()` | Cache-aside | Per-user per-book |
| `getUserQuizResults()` | Cache-aside | Per-user per-book |
| `getStudentQuizResults()` | Pass-through | Teacher reporting — cross-book aggregate |

### ActivityRepository Method Classification (6 methods)

| Method | Treatment | Notes |
|---|---|---|
| `getActivitiesByChapter()` | Cache-aside | By chapterId |
| `getActivityById()` | Cache-aside | Single row |
| `submitActivityResult()` | Write-through | Cache + remote if online |
| `getUserActivityResults()` | Cache-aside | Per-user |
| `getBestResult()` | Cache-aside | Per-user per-activity |
| `getActivityStats()` | Pass-through | Aggregate |

### Vocabulary Words: Read Path

Vocabulary words cached in `cached_vocabulary_words` are read through the existing `VocabularyRepository`. However, wrapping the full `VocabularyRepository` is out of scope (it handles the entire vocab learning system). Instead:

- **During download:** `BookDownloadService` fetches vocabulary words referenced by inline activities and writes them to `cached_vocabulary_words`.
- **During reading:** When an inline activity completes and tries to add words to the user's vocabulary, the `CachedBookRepository.saveInlineActivityResult()` checks `cached_vocabulary_words` for the word data. If offline, the word-add is queued along with the activity result.
- **No `CachedVocabularyRepository` needed** — the cache is a secondary read source used only by `BookDownloadService` and `CachedBookRepository` internals.

---

## Offline Chapter Completion

`markChapterComplete()` is the most complex method because it:
1. Fetches reading progress
2. Fetches all chapters (to count total)
3. Checks `book_has_quiz` via RPC
4. Updates reading progress with completion %
5. Awards XP via Edge Function
6. Checks assignments

**Offline behavior:**

```
markChapterComplete() offline:
  1. Read reading progress from cache
  2. Read all chapters from cache (already downloaded)
  3. Read quiz existence from cached_book_quizzes
  4. Calculate completion_percentage locally
  5. Set is_completed = true ONLY IF all chapters done AND (no quiz OR quiz_passed)
  6. Write updated progress to cache with is_dirty = 1
  7. Queue XP award and assignment check for sync
  8. Return Right(updatedProgress)
```

**On sync:** The dirty reading progress is upserted to remote. XP award and assignment check are replayed via their respective edge functions/RPCs. The server recalculates `is_completed` authoritatively — the local value is optimistic.

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
   - "Include audio" checkbox
   - Note: exact size shown after download completes (pre-calculation not feasible without server-side metadata)
3. `BookDownloadService` starts, same as above + audio if selected
4. Progress bar shown on BookDetailScreen
5. Book marked with "Downloaded" badge in library

### Download Service Orchestration

```
BookDownloadService.downloadBook(bookId, includeAudio):
  1. Set download_status = 'downloading'
  2. Fetch + cache book metadata
  3. Fetch + cache all chapters (single batch query)
  4. For each chapter (parallel, idempotent — skips already-cached):
     a. Fetch + cache content blocks (if use_content_blocks)
     b. Fetch + cache inline activities
     c. Fetch + cache legacy activities
     d. Download + cache images from content blocks
     e. Download + cache images from chapter.image_urls
     f. Download + cache images from activity questions (JSONB image_url)
     g. (if includeAudio) Download + cache audio files
  5. Fetch + cache book quiz (if exists)
  6. Collect all vocabulary word IDs from inline activities
  7. Fetch + cache vocabulary words (batch)
  8. Download + cache vocabulary word images/audio
  9. Fetch + cache reading progress
  10. Fetch + cache completed activity results
  11. Set download_status = 'complete'

  On any failure: set download_status = 'failed', partial cache retained.
  Resume: re-run downloadBook() — step 4 skips chapters whose data is already cached.
```

---

## Cache-Aside Read Pattern

Repository methods that support caching follow this pattern:

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

Uses existing `getChapters()` method (no new interface method needed). The batch query returns all chapters with their `updated_at` — compare against cached timestamps:

```dart
Future<void> _checkFreshnessInBackground(String bookId) async {
  final networkInfo = _networkInfo;
  if (!await networkInfo.isConnected) return;

  // Use existing getChapters() — returns all chapter data including updated_at
  final remoteResult = await _remoteRepo.getChapters(bookId);

  remoteResult.fold(
    (_) => null, // Network error — skip silently
    (remoteChapters) async {
      final localTimestamps = await _cacheStore.getChapterTimestamps(bookId);

      for (final chapter in remoteChapters) {
        if (chapter.updatedAt != localTimestamps[chapter.id]) {
          // Chapter changed — update cache + refresh its content blocks & activities
          await _cacheStore.saveChapter(bookId, chapter);
          // Re-download content blocks and activities for changed chapter
          await _refreshChapterContent(chapter.id);
        }
      }
    },
  );
}
```

**Trade-off:** This fetches full chapter data instead of just timestamps. This is acceptable because:
- It uses an existing interface method (no domain layer changes)
- The freshness check is fire-and-forget (non-blocking)
- Chapter data is relatively small (the heavy content is in content_blocks)

---

## File Cache (Images + Audio) and URL Rewriting

### File Cache Service

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

  /// Resolve a remote URL to local path if cached, otherwise return original URL
  Future<String> resolveUrl(String remoteUrl) async {
    final localPath = await _cacheStore.getLocalPath(remoteUrl);
    if (localPath != null && File(localPath).existsSync()) return localPath;
    return remoteUrl;
  }
}
```

### URL Rewriting for Images and Audio

Cached repositories return entities with **original remote URLs** — the URL rewriting happens at the widget/service layer:

**Images:** `CachedBookImage` widget wraps image display:
```dart
// Checks cached_files for local path, falls back to CachedNetworkImage
CachedBookImage(imageUrl: block.imageUrl, bookId: bookId)
```

**Audio:** `AudioSyncController` (in `audio_sync_provider.dart`) is modified to resolve URLs before playback:
```dart
// Before: _audioService.player.setUrl(block.audioUrl!);
// After:  _audioService.player.setUrl(await _fileCacheService.resolveUrl(block.audioUrl!));
//   - If cached: returns file:///path/to/local/audio.mp3
//   - If not cached: returns original https://... URL (streams from remote)
```

This approach means:
- Entities stay pure (no local path pollution)
- URL resolution is lazy and transparent
- Works for both cached and non-cached books

---

## Offline Progress Sync

### Writing Progress Offline

When offline, progress writes go to local cache with `is_dirty = 1`:
- `cached_reading_progress` — chapter position, reading time, completion
- `cached_inline_activity_results` — inline activity completions with full result data
- `cached_activity_results` — legacy activity results with full result JSON

XP awards and badge checks are queued in a separate `offline_pending_actions` list (in-memory or lightweight sqflite table).

### Syncing on Reconnect

`OfflineSyncService` uses existing `NetworkInfo.onConnectivityChanged` stream (from `lib/core/network/network_info.dart`):

```
Online detected:
  1. Find all cached_reading_progress WHERE is_dirty = 1
  2. For each: upsert to Supabase reading_progress via remote repo
  3. Find all cached_inline_activity_results WHERE is_dirty = 1
  4. For each: call saveInlineActivityResult() on remote repo
     - If remote returns false (already existed), discard — not an error
  5. Find all cached_activity_results WHERE is_dirty = 1
  6. For each: call submitActivityResult() on remote repo
  7. Process queued XP awards (call award_xp_transaction RPC)
  8. Process queued assignment checks
  9. Set is_dirty = 0 on all synced records
  10. Refresh reading progress from remote (server is authoritative for is_completed)
```

**Conflict resolution:** Server wins. After sync, reading progress is re-fetched from remote to get authoritative `is_completed` status (server checks quiz pass + chapter completion).

---

## Quick Wins (Independent of Cache System)

These eliminate redundant network calls regardless of caching:

| Issue | Fix | Impact |
|---|---|---|
| `chapterByIdProvider` re-fetches already-loaded chapter | Filter from `chaptersProvider` result | -1 network call per chapter open |
| `use_content_blocks` separate query | Add `useContentBlocks` to `ChapterModel.fromJson()` (column already exists in DB) | -1 network call per chapter open |
| `markChapterComplete` re-fetches all chapters | Read from Riverpod cache | -1 network call per chapter completion |

Note: `use_content_blocks` column already exists on `chapters` table — just not mapped in `ChapterModel.fromJson()`. No migration needed.

---

## New Files

```
lib/core/services/
  book_cache_database.dart        — sqflite DB initialization + schema
  book_cache_store.dart           — CRUD operations on all cache tables
  book_download_service.dart      — Orchestrates full book download
  file_cache_service.dart         — Image/audio file download + local storage
  offline_sync_service.dart       — Dirty record sync on reconnect (uses existing NetworkInfo)

lib/data/repositories/cached/
  cached_book_repository.dart     — Wraps SupabaseBookRepository (21 methods classified above)
  cached_content_block_repository.dart — Wraps SupabaseContentBlockRepository
  cached_book_quiz_repository.dart     — Wraps SupabaseBookQuizRepository
  cached_activity_repository.dart      — Wraps SupabaseActivityRepository

lib/presentation/providers/
  book_download_provider.dart     — Download state, progress, management

lib/presentation/screens/profile/
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
| `reader_body.dart` | Remove separate `use_content_blocks` query, read from chapter |
| `book_provider.dart` | Fix `chapterByIdProvider` to filter from batch |
| `profile_screen.dart` | Add "Downloaded Books" navigation link |
| `chapter_model.dart` | Map `use_content_blocks` in `fromJson()` |
| `chapter.dart` (entity) | Add `useContentBlocks` field |
| `audio_sync_provider.dart` | Use `FileCacheService.resolveUrl()` for audio URLs |

## Unchanged Layers

- All 117 UseCases
- All 21 Entities (except `Chapter` gains one field)
- All 38 Models (except `ChapterModel` gains one field)
- All domain repository interfaces
- All provider → usecase chains
- All screen → provider chains

---

## Downloaded Books Management Screen

Accessible from Profile screen. Shows:
- List of downloaded books with cover, title, chapter count
- Per-book storage size (text + images + audio separately, calculated from `cached_files.file_size` SUM)
- Total storage used across all downloads
- "Last read" date (from `cached_reading_progress`)
- "Remove Download" per book (deletes cache + files)
- "Remove All Downloads" bulk action

Removing a download:
1. Delete from `cached_books` (CASCADE removes all related rows)
2. Delete files from filesystem (`book_cache/{bookId}/`)
3. Reading progress is NOT deleted (stays on server)

---

## Multi-User Considerations

- `cached_books`, `cached_chapters`, `cached_content_blocks`, etc. are **shared** across users on same device — book content is user-independent
- `cached_reading_progress` and `cached_*_results` are **per-user** — keyed by `user_id`
- `download_status` on `cached_books` is per-device, not per-user — if user A downloads, user B benefits from the cache
- On user logout, dirty progress records should be synced first (if online) or warned about (if offline)
