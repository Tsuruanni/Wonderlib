# Book System Cleanup (Group D) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up duplicate code, dead code, type safety issues, schema drift, UX anti-patterns, and admin panel text in the Book System.

**Architecture:** Mechanical cleanup only — no business logic changes. Follows existing codebase patterns (Clean Architecture, owlio_shared enums, ConsumerWidget pattern).

**Tech Stack:** Flutter/Dart, Riverpod, Supabase, owlio_shared package

**Spec:** `docs/superpowers/specs/2026-03-27-book-system-cleanup-design.md`

---

## Task 1: Duplicate Enum Parsing + Hard-coded Strings (#11, #12, #13)

**Files:**
- Modify: `lib/data/models/book/book_model.dart`
- Modify: `lib/data/models/content/content_block_model.dart`
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart`

- [ ] **Step 1: Replace _parseBookStatus in BookModel**

In `lib/data/models/book/book_model.dart`:

1. In `fromJson` (~line 40), replace:
```dart
status: _parseBookStatus(json['status'] as String?),
```
with:
```dart
status: BookStatus.fromDbValue(json['status'] as String? ?? 'draft'),
```

2. Delete the `_parseBookStatus` method (~lines 133-142):
```dart
// DELETE THIS ENTIRE METHOD:
static BookStatus _parseBookStatus(String? status) {
  switch (status) {
    case 'published':
      return BookStatus.published;
    case 'archived':
      return BookStatus.archived;
    default:
      return BookStatus.draft;
  }
}
```

Ensure `BookStatus` is imported from owlio_shared (should already be).

- [ ] **Step 2: Replace _parseBlockType and _blockTypeToString in ContentBlockModel**

In `lib/data/models/content/content_block_model.dart`:

1. In `fromJson` (~line 33), replace:
```dart
type: _parseBlockType(json['type'] as String? ?? 'text'),
```
with:
```dart
type: ContentBlockType.fromDbValue(json['type'] as String? ?? 'text'),
```

2. In `toJson` (~line 115), replace:
```dart
'type': _blockTypeToString(type),
```
with:
```dart
'type': type.dbValue,
```

3. Delete both methods (~lines 82-108):
```dart
// DELETE _parseBlockType (lines 82-95)
// DELETE _blockTypeToString (lines 97-108)
```

Ensure `ContentBlockType` is imported from owlio_shared.

- [ ] **Step 3: Replace hard-coded 'published' strings**

In `lib/data/repositories/supabase/supabase_book_repository.dart`, replace all 4 occurrences:

```dart
// Line 31 — replace:
.eq('status', 'published')
// with:
.eq('status', BookStatus.published.dbValue)

// Line 78 — same replacement
// Line 104 — same replacement
// Line 132 — same replacement
```

Add import for `BookStatus` from owlio_shared if not already present.

- [ ] **Step 4: Run analyze**

```bash
dart analyze lib/data/models/book/book_model.dart lib/data/models/content/content_block_model.dart lib/data/repositories/supabase/supabase_book_repository.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/book/book_model.dart lib/data/models/content/content_block_model.dart lib/data/repositories/supabase/supabase_book_repository.dart
git commit -m "refactor: use shared enum methods instead of duplicate parsing logic"
```

---

## Task 2: Duplicate Code in Screens (#14, #15)

**Files:**
- Modify: `lib/presentation/screens/reader/reader_screen.dart`
- Modify: `lib/presentation/screens/profile/downloaded_books_screen.dart`

- [ ] **Step 1: Extract chapter completion method in ReaderScreen**

In `lib/presentation/screens/reader/reader_screen.dart`, the following block is duplicated in `_handleNextChapter` (~line 209), `_handleBackToBook` (~line 238), and `_handleTakeQuiz` (~line 266):

```dart
try {
  final completionNotifier = ref.read(chapterCompletionProvider.notifier);
  await completionNotifier.markComplete(
    bookId: bookId,
    chapterId: chapterId,
  );
} catch (e) {
  debugPrint('ChapterCompletionNotifier error: $e');
}
```

Extract to a private method:

```dart
Future<void> _markCurrentChapterComplete() async {
  try {
    final completionNotifier = ref.read(chapterCompletionProvider.notifier);
    await completionNotifier.markComplete(
      bookId: bookId,
      chapterId: chapterId,
    );
  } catch (e) {
    debugPrint('ChapterCompletionNotifier error: $e');
  }
}
```

Replace all 3 occurrences with `await _markCurrentChapterComplete();`.

Note: Read the file first to verify `bookId` and `chapterId` are accessible from the method scope (they should be instance/local variables in the state class). If they're method parameters, pass them to `_markCurrentChapterComplete`.

- [ ] **Step 2: Remove _formatBytes from DownloadedBooksScreen**

In `lib/presentation/screens/profile/downloaded_books_screen.dart`:

1. Find `_formatBytes` method (~lines 85-91) and delete it entirely.

2. Find where it's called (~line 50):
```dart
final totalFormatted = _formatBytes(totalBytes);
```

Replace with a direct formatting using the same logic but inline, or better — compute total from the `DownloadedBookInfo` list:
```dart
// If totalBytes is computed from the list items, each item already has formattedSize.
// For the total, use the same inline logic:
String _formatTotalBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
```

Actually — read the file to see how `totalBytes` is used. If it's only for a total storage display, keep a single formatting function but name it `_formatTotalSize` to avoid confusion with `info.formattedSize` (which is per-item). The goal is to not have duplicate logic — the per-item formatting should use `info.formattedSize`.

- [ ] **Step 3: Run analyze and commit**

```bash
dart analyze lib/presentation/screens/reader/reader_screen.dart lib/presentation/screens/profile/downloaded_books_screen.dart
git add lib/presentation/screens/reader/reader_screen.dart lib/presentation/screens/profile/downloaded_books_screen.dart
git commit -m "refactor: extract duplicated chapter completion and remove formatBytes duplication"
```

---

## Task 3: Dead Code Removal (#17-#22)

**Files:**
- Delete: `lib/domain/usecases/activity/get_user_activity_results_usecase.dart`
- Delete: `lib/domain/usecases/reading/get_user_reading_history_usecase.dart`
- Delete: `lib/domain/usecases/book/get_chapter_by_id_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart` (remove 2 providers)
- Modify: `lib/presentation/providers/book_provider.dart` (remove ReadingController)
- Modify: `lib/presentation/providers/library_provider.dart` (remove 3 providers)
- Modify: `lib/domain/repositories/content_block_repository.dart` (remove method)
- Modify: `lib/data/repositories/supabase/supabase_content_block_repository.dart` (remove method)
- Modify: `lib/data/repositories/cached/cached_content_block_repository.dart` (remove method)

- [ ] **Step 1: Delete unused UseCase files**

Delete these 3 files:
```bash
rm lib/domain/usecases/activity/get_user_activity_results_usecase.dart
rm lib/domain/usecases/reading/get_user_reading_history_usecase.dart
rm lib/domain/usecases/book/get_chapter_by_id_usecase.dart
```

Before deleting, verify each has no callers: `grep -r "GetUserActivityResultsUseCase\|get_user_activity_results" lib/` etc.

- [ ] **Step 2: Remove dead providers from usecase_providers.dart**

In `lib/presentation/providers/usecase_providers.dart`:

1. Remove `getUserReadingHistoryUseCaseProvider` definition and its import
2. Remove `getChapterByIdUseCaseProvider` definition and its import

Search for each provider name in the codebase first to confirm no consumers.

- [ ] **Step 3: Remove ReadingController from book_provider.dart**

In `lib/presentation/providers/book_provider.dart`:

1. Find the `ReadingController` class and `readingControllerProvider` definition
2. Delete both entirely

Verify no file references `readingControllerProvider`: `grep -r "readingControllerProvider" lib/`

- [ ] **Step 4: Remove orphaned providers from library_provider.dart**

In `lib/presentation/providers/library_provider.dart`:

Remove these 3 providers (keep `librarySearchQueryProvider`, `isSearchActiveProvider`, and `cefrLevels`):
- `libraryViewModeProvider` (and `LibraryViewMode` enum)
- `selectedLevelProvider`
- `filteredBooksProvider`

Verify no file references them: `grep -r "libraryViewModeProvider\|selectedLevelProvider\|filteredBooksProvider" lib/`

The file should be left with only:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search query state
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

/// Whether search is active
final isSearchActiveProvider = StateProvider<bool>((ref) => false);

/// Available CEFR levels for filtering
const cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
```

Remove unused imports after cleanup.

- [ ] **Step 5: Remove getContentBlockById from repository chain**

1. In `lib/domain/repositories/content_block_repository.dart`, remove:
```dart
Future<Either<Failure, ContentBlock>> getContentBlockById(String blockId);
```

2. In `lib/data/repositories/supabase/supabase_content_block_repository.dart`, remove the `getContentBlockById` method implementation.

3. In `lib/data/repositories/cached/cached_content_block_repository.dart`, remove the `getContentBlockById` method implementation.

Verify no external callers: `grep -r "getContentBlockById" lib/`

- [ ] **Step 6: Run analyze and commit**

```bash
dart analyze lib/
git add -A
git commit -m "chore: remove dead code — unused UseCases, providers, and repository methods"
```

---

## Task 4: Schema Drift + Type Safety (#26, #27, #28)

**Files:**
- Modify: `lib/domain/entities/book.dart`
- Modify: `lib/data/models/book/book_model.dart`
- Modify: `lib/presentation/screens/library/book_detail_screen.dart`
- Modify: any files using `book.metadata['author']`

- [ ] **Step 1: Add author field to Book entity**

In `lib/domain/entities/book.dart`, add to the fields:

```dart
final String? author;
```

Add it to the constructor and `props` list (entity extends Equatable). Read the file to see the exact pattern.

Note: Check if `coverUrl` already maps to the `cover_image_url` DB column. If yes, no need to add `coverImageUrl`. If `coverUrl` maps to something else, add `coverImageUrl` too.

- [ ] **Step 2: Add author to BookModel**

In `lib/data/models/book/book_model.dart`:

1. In `fromJson`, add:
```dart
author: json['author'] as String?,
```

2. In `toJson`, add:
```dart
'author': author,
```

3. In `toEntity()`, add `author: author` to the Book constructor call.

4. Add `author` field to the BookModel class.

- [ ] **Step 3: Update screens using metadata['author']**

Search for `metadata['author']` usage:
```bash
grep -rn "metadata\['author'\]" lib/
```

Replace each occurrence with `book.author`. Expected locations:
- `lib/presentation/widgets/book/book_list_tile.dart` (~line 144)
- `lib/presentation/screens/library/book_detail_screen.dart` (~line 152)

- [ ] **Step 4: Fix dynamic types in BookDetailScreen**

In `lib/presentation/screens/library/book_detail_screen.dart`:

1. Change `_ProgressSection` field (~line 472):
```dart
// Before:
final dynamic progress;
// After:
final ReadingProgress? progress;
```

Update all property accesses within `_ProgressSection` to use null-safe operators if needed.

2. Change `_BookDetailFAB` field (~line 352):
```dart
// Before:
final AsyncValue<dynamic> chaptersAsync;
final dynamic progress;
// After:
final AsyncValue<List<ChapterWithLockStatus>> chaptersAsync;
final ReadingProgress? progress;
```

Update the constructor call site to pass correctly typed values. Add necessary imports.

- [ ] **Step 5: Run analyze and commit**

```bash
dart analyze lib/
git add lib/domain/entities/book.dart lib/data/models/book/book_model.dart lib/presentation/screens/library/book_detail_screen.dart lib/presentation/widgets/book/book_list_tile.dart
git commit -m "fix: add author field to Book entity, fix dynamic types in BookDetailScreen"
```

---

## Task 5: ActivityStats Typed Entity (#29)

**Files:**
- Create: `lib/domain/entities/activity_stats.dart`
- Modify: `lib/domain/repositories/activity_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_activity_repository.dart`
- Modify: `lib/domain/usecases/activity/get_activity_stats_usecase.dart`

- [ ] **Step 1: Discover the actual stats fields**

Read `lib/data/repositories/supabase/supabase_activity_repository.dart` to find the `getActivityStats` implementation. See what fields the returned map contains. Also check if a cached implementation exists.

- [ ] **Step 2: Create ActivityStats entity**

Based on the discovered fields, create `lib/domain/entities/activity_stats.dart`:

```dart
import 'package:equatable/equatable.dart';

class ActivityStats extends Equatable {
  const ActivityStats({
    // Add typed fields matching what the repository returns
    // e.g.: required this.totalActivities, required this.completedActivities, etc.
  });

  // Fields here

  @override
  List<Object?> get props => [/* all fields */];
}
```

- [ ] **Step 3: Update repository interface**

In `lib/domain/repositories/activity_repository.dart`, change:
```dart
// Before:
Future<Either<Failure, Map<String, dynamic>>> getActivityStats(String userId);
// After:
Future<Either<Failure, ActivityStats>> getActivityStats(String userId);
```

- [ ] **Step 4: Update repository implementation**

In the Supabase repository, update the return to construct an `ActivityStats` instance from the response data. Also update cached repo if it exists.

- [ ] **Step 5: Update UseCase**

In `lib/domain/usecases/activity/get_activity_stats_usecase.dart`, change the return type from `Map<String, dynamic>` to `ActivityStats`.

- [ ] **Step 6: Update any consumers**

Search for `getActivityStatsUseCaseProvider` or `activityStats` usage in presentation layer and update to use typed fields.

- [ ] **Step 7: Run analyze and commit**

```bash
dart analyze lib/
git add lib/domain/entities/activity_stats.dart lib/domain/repositories/activity_repository.dart lib/data/repositories/ lib/domain/usecases/activity/get_activity_stats_usecase.dart
git commit -m "refactor: replace Map<String, dynamic> with typed ActivityStats entity"
```

---

## Task 6: Library Screen UX Fixes (#32, #33, #36)

**Files:**
- Modify: `lib/presentation/screens/library/library_screen.dart`

- [ ] **Step 1: Convert _BookShelfItem and _LibraryShelf to ConsumerWidget**

In `lib/presentation/screens/library/library_screen.dart`:

1. Change `_LibraryShelf` (~line 278):
```dart
// Before:
class _LibraryShelf extends StatelessWidget {
  final String level;
  final List<Book> books;
  final WidgetRef ref;
  const _LibraryShelf({required this.level, required this.books, required this.ref});

// After:
class _LibraryShelf extends ConsumerWidget {
  final String level;
  final List<Book> books;
  const _LibraryShelf({required this.level, required this.books});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

Remove `ref` from all call sites that construct `_LibraryShelf`.

2. Same for `_BookShelfItem` (~line 392):
```dart
// Before:
class _BookShelfItem extends StatelessWidget {
  final Book book;
  final WidgetRef ref;
  const _BookShelfItem({required this.book, required this.ref});

// After:
class _BookShelfItem extends ConsumerWidget {
  final Book book;
  const _BookShelfItem({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

Remove `ref` from all constructor call sites.

- [ ] **Step 2: Replace Image.network with CachedBookImage**

First, find the project's cached image widget:
```bash
grep -r "CachedBookImage\|CachedNetworkImage\|cached_book_image" lib/presentation/widgets/
```

In `library_screen.dart` (~line 454), replace:
```dart
Image.network(
  book.coverUrl ?? '',
  fit: BoxFit.cover,
  errorBuilder: (_, __, ___) => Container(
    color: AppColors.neutral.withOpacity(0.2),
    child: Center(child: Icon(Icons.menu_book_rounded, size: 40, color: AppColors.neutralText))
  ),
),
```

with the project's cached image widget (adapt to actual widget name found above).

- [ ] **Step 3: Add autoDispose to selectedCategoryProvider**

In `library_screen.dart` (~line 21):
```dart
// Before:
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
// After:
final selectedCategoryProvider = StateProvider.autoDispose<String?>((ref) => null);
```

- [ ] **Step 4: Run analyze and commit**

```bash
dart analyze lib/presentation/screens/library/library_screen.dart
git add lib/presentation/screens/library/library_screen.dart
git commit -m "fix: convert to ConsumerWidget, use cached images, add autoDispose to category filter"
```

---

## Task 7: hasReadToday Timezone Fix (#35)

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_book_repository.dart`

- [ ] **Step 1: Fix hasReadToday to use daily_chapter_reads**

In `lib/data/repositories/supabase/supabase_book_repository.dart`, replace the `hasReadToday` method (~lines 527-545):

```dart
// Before: queries reading_progress.updated_at with local time
@override
Future<Either<Failure, bool>> hasReadToday(String userId) async {
  try {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final response = await _supabase
        .from(DbTables.readingProgress)
        .select('id')
        .eq('user_id', userId)
        .gte('updated_at', todayStart)
        .limit(1);
    return Right((response as List).isNotEmpty);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}

// After: queries daily_chapter_reads with DATE comparison (timezone-safe)
@override
Future<Either<Failure, bool>> hasReadToday(String userId) async {
  try {
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final response = await _supabase
        .from(DbTables.dailyChapterReads)
        .select('id')
        .eq('user_id', userId)
        .eq('read_date', today)
        .limit(1);
    return Right((response as List).isNotEmpty);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

Note: `daily_chapter_reads.read_date` is a DATE column populated by `_logDailyChapterRead`. Verify `DbTables.dailyChapterReads` constant exists and the column name is `read_date`.

- [ ] **Step 2: Run analyze and commit**

```bash
dart analyze lib/data/repositories/supabase/supabase_book_repository.dart
git add lib/data/repositories/supabase/supabase_book_repository.dart
git commit -m "fix: use daily_chapter_reads for hasReadToday to avoid timezone mismatch"
```

---

## Task 8: BookDownloader UseCase Extraction (#34)

**Files:**
- Create: `lib/domain/usecases/book/download_book_usecase.dart`
- Create: `lib/domain/usecases/book/remove_book_download_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/book_download_provider.dart`

- [ ] **Step 1: Read the download service interface**

Read `lib/presentation/providers/book_download_provider.dart` to understand:
- What `bookDownloadServiceProvider` provides (type, methods)
- What `fileCacheServiceProvider` provides
- What `bookCacheStoreProvider` provides
- How `downloadBook` and `removeDownload` work

Also check if there's a repository interface these services could live behind, or if we need to create one.

- [ ] **Step 2: Create DownloadBookUseCase**

Create `lib/domain/usecases/book/download_book_usecase.dart`. The UseCase should wrap the `bookDownloadService.downloadBook()` call. It takes bookId, userId, includeAudio and returns success/failure. Progress callback stays in the provider (UI concern).

Read the actual service to determine the right abstraction. The UseCase may need a `BookDownloadRepository` interface in the domain layer if one doesn't exist.

- [ ] **Step 3: Create RemoveBookDownloadUseCase**

Create `lib/domain/usecases/book/remove_book_download_usecase.dart`. Wraps the file deletion + cache deletion logic.

- [ ] **Step 4: Register providers and update BookDownloader**

In `usecase_providers.dart`, register both UseCases.

In `book_download_provider.dart`, replace direct service calls with UseCase calls. Keep provider invalidation and progress tracking in the provider.

- [ ] **Step 5: Run analyze and commit**

```bash
dart analyze lib/
git add lib/domain/usecases/book/download_book_usecase.dart lib/domain/usecases/book/remove_book_download_usecase.dart lib/presentation/providers/usecase_providers.dart lib/presentation/providers/book_download_provider.dart
git commit -m "refactor: extract book download/remove operations to UseCases"
```

---

## Task 9: Admin Panel Fixes (#37, #38)

**Files:**
- Modify: `owlio_admin/lib/features/books/screens/book_list_screen.dart`
- Modify: `owlio_admin/lib/features/books/screens/book_edit_screen.dart`
- Modify: `owlio_admin/lib/features/books/screens/chapter_edit_screen.dart`

- [ ] **Step 1: Translate Turkish strings in book_list_screen.dart**

In `owlio_admin/lib/features/books/screens/book_list_screen.dart`, replace:

| Line | Turkish | English |
|------|---------|---------|
| ~29 | `'Kitaplar'` | `'Books'` |
| ~38 | `'JSON İçe Aktar'` | `'Import JSON'` |
| ~44 | `'Yeni Kitap'` | `'New Book'` |
| ~63 | `'Henüz kitap yok'` | `'No books yet'` |
| ~73 | `'İlk kitabınızı oluşturun'` | `'Create your first book'` |
| ~102 | `'Hata: $error'` | `'Error: $error'` |
| ~106 | `'Tekrar Dene'` | `'Retry'` |
| ~180 | `'Yazar: ${book['author']}'` | `'Author: ${book['author']}'` |
| ~198 | `'$chapterCount bölüm'` | `'$chapterCount chapters'` |
| ~203 | `'Yayında'` | `'Published'` |
| ~208 | `'Taslak'` | `'Draft'` |

- [ ] **Step 2: Translate Turkish strings in other admin book screens**

Read `book_edit_screen.dart` and `chapter_edit_screen.dart` for Turkish strings and replace with English equivalents.

- [ ] **Step 3: Fix _getLevelColor to use CEFR values**

In `book_list_screen.dart`, replace `_getLevelColor` (~lines 240-251):

```dart
// Before:
Color _getLevelColor(String level) {
  switch (level.toLowerCase()) {
    case 'beginner':
      return Colors.green;
    case 'intermediate':
      return Colors.orange;
    case 'advanced':
      return Colors.red;
    default:
      return Colors.blue;
  }
}

// After:
Color _getLevelColor(String level) {
  switch (level.toUpperCase()) {
    case 'A1':
      return Colors.green;
    case 'A2':
      return Colors.lightGreen;
    case 'B1':
      return Colors.orange;
    case 'B2':
      return Colors.deepOrange;
    case 'C1':
      return Colors.red;
    case 'C2':
      return Colors.purple;
    default:
      return Colors.blue;
  }
}
```

- [ ] **Step 4: Run analyze and commit**

```bash
dart analyze owlio_admin/lib/
git add owlio_admin/lib/features/books/screens/
git commit -m "fix: translate admin book screens to English, fix CEFR level colors"
```

---

## Task 10: Update Audit Spec Status

**Files:**
- Modify: `docs/specs/01-book-system.md`

- [ ] **Step 1: Update finding statuses**

In `docs/specs/01-book-system.md`, update Status column for all Group D findings:

| # | Status |
|---|--------|
| 11 | Fixed |
| 12 | Fixed |
| 13 | Fixed |
| 14 | Fixed |
| 15 | Fixed |
| 17 | Fixed |
| 18 | Fixed |
| 19 | Fixed |
| 20 | Fixed |
| 21 | Fixed |
| 22 | Fixed |
| 26 | Fixed |
| 27 | Fixed |
| 28 | Fixed |
| 29 | Fixed |
| 32 | Fixed |
| 33 | Fixed |
| 34 | Fixed |
| 35 | Fixed |
| 36 | Fixed |
| 37 | Fixed |
| 38 | Fixed |

- [ ] **Step 2: Commit**

```bash
git add docs/specs/01-book-system.md docs/superpowers/specs/2026-03-27-book-system-cleanup-design.md
git commit -m "docs: update book system audit — all findings resolved"
```
