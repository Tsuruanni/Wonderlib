# Book System Cleanup (Group D)

Mechanical cleanup fixes from the Book System audit (`docs/specs/01-book-system.md`), findings #11-#22, #26-#29, #32-#38.

**Scope:** Duplicate code removal, dead code deletion, type safety fixes, schema drift, UX anti-patterns, admin panel fixes.

**Approach:** Six batches of related fixes, executed sequentially. No business logic changes — purely cleanup.

---

## Batch 1: Duplicate Enum Parsing + Hard-coded Strings (#11, #12, #13)

### 1.1 BookModel._parseBookStatus (#11)

**Problem:** `BookModel` has a private `_parseBookStatus()` switch that duplicates `BookStatus.fromDbValue()` from owlio_shared.

**Fix:** Replace `_parseBookStatus(json['status'] as String?)` with `BookStatus.fromDbValue(json['status'] as String? ?? 'draft')`. Delete the `_parseBookStatus` method.

**File:** `lib/data/models/book/book_model.dart`

### 1.2 ContentBlockModel._parseBlockType (#12)

**Problem:** `ContentBlockModel` has `_parseBlockType()` and `_blockTypeToString()` that duplicate `ContentBlockType.fromDbValue()` and `.dbValue`.

**Fix:** Replace with shared enum methods. Delete both private methods.

**File:** `lib/data/models/content/content_block_model.dart`

### 1.3 Hard-coded 'published' String (#13)

**Problem:** `supabase_book_repository.dart` uses `.eq('status', 'published')` in 4 places instead of `BookStatus.published.dbValue`.

**Fix:** Replace all 4 occurrences with `BookStatus.published.dbValue`.

**File:** `lib/data/repositories/supabase/supabase_book_repository.dart`

---

## Batch 2: Duplicate Code in Screens (#14, #15)

### 2.1 Chapter Completion try/catch (#14)

**Problem:** `ReaderScreen` has identical `try/catch` blocks calling `chapterCompletionProvider.notifier.markComplete(...)` in `_handleNextChapter`, `_handleBackToBook`, and `_handleTakeQuiz`.

**Fix:** Extract to a private method `_markCurrentChapterComplete()` and call it from all three handlers.

**File:** `lib/presentation/screens/reader/reader_screen.dart`

### 2.2 _formatBytes Duplication (#15)

**Problem:** `DownloadedBooksScreen` has `_formatBytes` private method that duplicates `DownloadedBookInfo.formattedSize` getter.

**Fix:** Delete `_formatBytes` from the screen, use `item.formattedSize` instead.

**File:** `lib/presentation/screens/profile/downloaded_books_screen.dart`

---

## Batch 3: Dead Code Removal (#17-#22)

### 3.1 GetUserActivityResultsUseCase (#17)

**Delete:** `lib/domain/usecases/activity/get_user_activity_results_usecase.dart` — no provider, no callers.

### 3.2 GetUserReadingHistoryUseCase (#18)

**Delete:** `lib/domain/usecases/reading/get_user_reading_history_usecase.dart` — provider exists but never consumed.
**Also delete:** `getUserReadingHistoryUseCaseProvider` from `usecase_providers.dart`.

### 3.3 readingControllerProvider (#19)

**Delete:** The `ReadingController` class and `readingControllerProvider` from `lib/presentation/providers/book_provider.dart` — never consumed.

### 3.4 getChapterByIdUseCaseProvider (#20)

**Delete:** `getChapterByIdUseCaseProvider` from `usecase_providers.dart` — screens use `chapterByIdProvider` instead.
**Also delete:** `lib/domain/usecases/book/get_chapter_by_id_usecase.dart` if it has no other consumers.

### 3.5 Orphaned Library Providers (#21)

**Delete from `lib/presentation/providers/library_provider.dart`:** `libraryViewModeProvider`, `selectedLevelProvider`, `filteredBooksProvider` — shadowed by local providers in `library_screen.dart`.

### 3.6 ContentBlockRepository.getContentBlockById (#22)

**Remove:** `getContentBlockById` method from `ContentBlockRepository` interface and all implementations (supabase, cached). No external callers.

---

## Batch 4: Schema Drift + Type Safety (#26, #27, #28, #29)

### 4.1 Book author/cover_image_url Not in Model (#26)

**Problem:** `books` table has `author` and `cover_image_url` columns (migration `20260202000003`) but `BookModel`/`Book` entity doesn't map them. UI reads `book.metadata['author']` as workaround.

**Fix:**
- Add `author` and `coverImageUrl` fields to `Book` entity (nullable Strings)
- Add `author` and `cover_image_url` to `BookModel.fromJson()` and `toJson()`
- Update UI that reads `book.metadata['author']` to use `book.author` instead

**Files:** `lib/domain/entities/book.dart`, `lib/data/models/book/book_model.dart`, `lib/presentation/widgets/book/book_list_tile.dart` (~line 144), `lib/presentation/screens/library/book_detail_screen.dart` (~line 152)

### 4.2 _ProgressSection.progress Typed as dynamic (#27)

**Problem:** `_ProgressSection` widget in `BookDetailScreen` has `final dynamic progress` — should be `ReadingProgress`.

**Fix:** Change to `final ReadingProgress progress` and update the constructor.

**File:** `lib/presentation/screens/library/book_detail_screen.dart`

### 4.3 _BookDetailFAB.chaptersAsync Typed as dynamic (#28)

**Problem:** `_BookDetailFAB` has `final AsyncValue<dynamic> chaptersAsync` — should be `AsyncValue<List<Chapter>>`.

**Fix:** Change type and update constructor.

**File:** `lib/presentation/screens/library/book_detail_screen.dart`

### 4.4 ActivityRepository.getActivityStats Returns Untyped Map (#29)

**Problem:** `getActivityStats` returns `Map<String, dynamic>` — no typed entity.

**Fix:** Create `ActivityStats` entity with typed fields matching the returned data. Update repository interface, implementation, and UseCase. Read the repository implementation first to discover what fields the map actually contains.

> **Complexity note:** This is more than mechanical cleanup — requires reading the data layer, creating a new entity, and updating the full chain. Take extra care.

**Files:** Create entity at `lib/domain/entities/activity_stats.dart`, modify `lib/domain/repositories/activity_repository.dart`, `lib/data/repositories/supabase/supabase_activity_repository.dart`, `lib/domain/usecases/activity/get_activity_stats_usecase.dart`

---

## Batch 5: UX / Data Fixes (#32, #33, #34, #35, #36)

### 5.1 WidgetRef in Constructor (#32)

**Problem:** `_BookShelfItem` and `_LibraryShelf` pass `WidgetRef ref` as constructor parameter — anti-pattern.

**Fix:** Convert both to `ConsumerWidget` or `ConsumerStatelessWidget`, remove `ref` from constructor.

**File:** `lib/presentation/screens/library/library_screen.dart`

### 5.2 Image.network Instead of CachedBookImage (#33)

**Problem:** `LibraryScreen` uses `Image.network` for book covers — not disk-cached.

**Fix:** Replace with the project's `CachedBookImage` widget (find it in `lib/presentation/widgets/`).

**File:** `lib/presentation/screens/library/library_screen.dart`

### 5.3 BookDownloader Bypasses UseCase Layer (#34)

**Problem:** `BookDownloader` provider directly calls `fileCacheServiceProvider` and `bookCacheStoreProvider`, bypassing UseCases.

**Fix:** Create `DownloadBookUseCase` and `RemoveBookDownloadUseCase` that wrap the data-layer calls. The provider calls the UseCases instead.

> **Complexity note:** This requires reading the download orchestration code, creating 2 UseCases with proper repository dependencies, and rewiring the provider. More than mechanical cleanup.

**Files:** Create 2 UseCases, modify `lib/presentation/providers/book_download_provider.dart`

### 5.4 hasReadToday Timezone Mismatch (#35)

**Problem:** `hasReadToday` in `supabase_book_repository.dart` uses `DateTime.now()` (device local time) to check against UTC `updated_at`. Timezone mismatch.

**Fix:** Query `daily_chapter_reads` table with `read_date = today` instead of comparing timestamps on `reading_progress.updated_at`. The `daily_chapter_reads` table already stores a DATE column and is the canonical source for "read today" checks (also used by the daily quest engine).

**File:** `lib/data/repositories/supabase/supabase_book_repository.dart`

### 5.5 selectedCategoryProvider Without autoDispose (#36)

**Problem:** `selectedCategoryProvider` in `library_screen.dart` persists filter state across screen visits.

**Fix:** Add `.autoDispose` to the provider.

**File:** `lib/presentation/screens/library/library_screen.dart`

---

## Batch 6: Admin Panel Fixes (#37, #38)

### 6.1 Turkish UI Text (#37)

**Problem:** Admin book screens use Turkish text ("Kitaplar", "Yeni Kitap", "Henüz kitap yok", etc.). CLAUDE.md says "UI in English."

**Fix:** Replace all Turkish strings with English equivalents in admin book screens.

**Files:** `owlio_admin/lib/features/books/screens/book_list_screen.dart`, `book_edit_screen.dart`, `chapter_edit_screen.dart`

### 6.2 _getLevelColor Wrong Enum Values (#38)

**Problem:** `_getLevelColor` uses `'beginner'`/`'intermediate'`/`'advanced'` strings that don't match CEFR level values (`A1`, `A2`, `B1`, etc.).

**Fix:** Update the switch to use CEFR values from `CEFRLevel` enum, or the actual level strings stored in the database.

**File:** `owlio_admin/lib/features/books/screens/book_list_screen.dart`

---

## Out of Scope

- Admin deep audit (JSON import logic, chapter editor, content block editor) — separate session
- XP balancing (quiz vs non-quiz book rewards) — separate session

## Verification

After all batches:
- `dart analyze lib/` must pass
- `dart analyze owlio_admin/lib/` must pass
- No behavioral changes — same features, cleaner code
