# Book System

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Idempotency | Chapter/book completion XP has no DB-level idempotency — only in-memory `wasAlreadyCompleted` cache check. Race conditions can award duplicate XP. Inline activity XP has proper UNIQUE constraint. | High | Fixed |
| 2 | Idempotency | Quiz XP awarded on every passing attempt. `_handleQuizPassed` guards `quiz_passed` flag but the controller still calls `addXP(xpQuizPass)` on retakes. | High | Fixed |
| 3 | Architecture | Quiz grading logic (`_gradeQuestion`, `_isAnswerValid`, score accumulation) lives in `BookQuizScreen` widget instead of a UseCase. | Medium | Fixed |
| 4 | Architecture | `handleInlineActivityCompletion` is a free function taking `WidgetRef` — effectively a UseCase in the presentation layer. | Medium | Fixed |
| 5 | Architecture | Chapter sequential-lock algorithm computed in `BookDetailScreen.build()` — business rule in widget. | Medium | Fixed |
| 6 | Architecture | Book access lock computation in `bookLockProvider` — domain logic embedded in FutureProvider. | Medium | Fixed |
| 7 | Architecture | `_handleQuizPassed` in `SupabaseBookQuizRepository` contains multi-step business logic (fetch progress → fetch chapters → compute completion → update progress). Should be a UseCase. | Medium | Fixed |
| 8 | Error Handling | All `FutureProvider` book providers silently return empty list/null on failure, bypassing `.when(error:...)` branch. Only `contentBlocksProvider` correctly propagates errors. | Medium | Fixed |
| 9 | RLS | `reading_progress` has `FOR ALL` policy — students can DELETE their own reading progress rows. Almost certainly unintended. | Medium | Fixed |
| 10 | RLS | `book_quizzes` admin policy uses role `head_teacher` but system uses `head`. Head-role teachers may be blocked from quiz management. | Medium | N/A (already fixed) |
| 11 | Duplicate Code | `BookModel._parseBookStatus()` duplicates `BookStatus.fromDbValue()` from owlio_shared. | Low | TODO |
| 12 | Duplicate Code | `ContentBlockModel._parseBlockType()`/`_blockTypeToString()` duplicates `ContentBlockType.fromDbValue()`/`.dbValue`. | Low | TODO |
| 13 | Duplicate Code | Hard-coded `'published'` string in 4 places in `supabase_book_repository.dart`. Should use `BookStatus.published.dbValue`. | Low | TODO |
| 14 | Duplicate Code | Chapter completion `try/catch` block duplicated 3 times in `ReaderScreen` (`_handleNextChapter`, `_handleBackToBook`, `_handleTakeQuiz`). | Low | TODO |
| 15 | Duplicate Code | `_formatBytes` duplicated between `DownloadedBooksScreen` and `DownloadedBookInfo.formattedSize`. | Low | TODO |
| 16 | Duplicate Code | Book completion logic partially duplicated between `SupabaseBookRepository.markChapterComplete` and `SupabaseBookQuizRepository._handleQuizPassed`. | Low | Fixed (via #7) |
| 17 | Dead Code | `GetUserActivityResultsUseCase` — no provider registered, no callers. | Low | TODO |
| 18 | Dead Code | `GetUserReadingHistoryUseCase` + `getUserReadingHistoryUseCaseProvider` — provider defined but never consumed by any screen/provider. | Low | TODO |
| 19 | Dead Code | `readingControllerProvider` (`ReadingController`) — registered but never consumed. | Low | TODO |
| 20 | Dead Code | `getChapterByIdUseCaseProvider` — registered in `usecase_providers.dart` but never used (screens use `chapterByIdProvider` which filters from cached `chaptersProvider`). | Low | TODO |
| 21 | Dead Code | `libraryViewModeProvider`, `selectedLevelProvider`, `filteredBooksProvider` in `library_provider.dart` — shadowed by local providers in `library_screen.dart`. | Low | TODO |
| 22 | Dead Code | `ContentBlockRepository.getContentBlockById` — declared in interface, implemented in repos, but no UseCase wraps it and nothing calls it externally. | Low | TODO |
| 23 | Performance | `_updateAssignmentProgress` calls `CalculateUnitProgressUseCase` RPC for every unit assignment on every chapter completion, regardless of whether the book belongs to that unit. | Medium | Deferred (no client-side filter possible) |
| 24 | Performance | `book_has_quiz` RPC called twice during `markChapterComplete` when all chapters complete — once in repository, once in notifier. | Low | Fixed (via #7) |
| 25 | Performance | Missing `autoDispose` on `booksProvider`, `bookByIdProvider`, `chaptersProvider`, `readingProgressProvider`, `completedBookIdsProvider`, `completedInlineActivitiesProvider`, `contentBlocksProvider` — memory accumulation in long sessions. | Low | Fixed |
| 26 | Schema Drift | `author` and `cover_image_url` columns exist in `books` table (migration `20260202000003`) but not mapped in `BookModel`/`Book` entity. UI uses `book.metadata['author']` as workaround. | Low | TODO |
| 27 | Type Safety | `_ProgressSection.progress` typed as `dynamic` in `BookDetailScreen`. Should be `ReadingProgress`. | Low | TODO |
| 28 | Type Safety | `_BookDetailFAB.chaptersAsync` typed as `AsyncValue<dynamic>`. Should be `AsyncValue<List<Chapter>>`. | Low | TODO |
| 29 | Type Safety | `ActivityRepository.getActivityStats` returns `Map<String, dynamic>` — no typed entity. | Low | TODO |
| 30 | UX | Library categories error silently shows empty `SizedBox` — no user feedback. | Low | Fixed |
| 31 | UX | Raw error strings (`'Error: $error'`) shown to user in `BookDetailScreen` and `LibraryScreen` instead of shared `ErrorStateWidget`. | Low | Fixed |
| 32 | UX | `_BookShelfItem` and `_LibraryShelf` pass `WidgetRef` as constructor parameter — anti-pattern, should be `ConsumerWidget`. | Low | TODO |
| 33 | UX | `Image.network` used in `LibraryScreen` instead of project's `CachedBookImage` widget — library covers not disk-cached. | Low | TODO |
| 34 | Architecture | `BookDownloader` provider directly calls data-layer services (`fileCacheServiceProvider`, `bookCacheStoreProvider`), bypassing UseCase layer. | Low | TODO |
| 35 | Data | `hasReadToday` uses device local time vs UTC `updated_at` — timezone mismatch possible. | Low | TODO |
| 36 | Data | `selectedCategoryProvider` without `autoDispose` — filter state persists across library screen visits (likely unintended). | Low | TODO |
| 37 | Admin | Admin panel book screens use Turkish UI text — violates CLAUDE.md "UI in English" rule. | Low | TODO |
| 38 | Admin | `_getLevelColor` in admin `book_list_screen.dart` uses `'beginner'`/`'intermediate'`/`'advanced'` strings that don't match CEFR enum values (`A1`, `A2`, `B1`...) — switch never matches. | Low | TODO |

### Checklist Result

- **Architecture Compliance**: 5 issues (#3, #4, #5, #6, #7) — business logic in widgets/providers, quiz grading outside domain layer
- **Code Quality**: 6 issues (#11-#16) — enum parsing duplication, hard-coded strings, repeated code blocks
- **Dead Code**: 6 issues (#17-#22) — unused UseCases, providers, and repository methods
- **Database & Security**: 2 issues (#9, #10) — RLS allows student progress deletion, role mismatch in quiz policy
- **Edge Cases & UX**: 5 issues (#8, #30, #31, #32, #33) — silent failure swallowing, raw error strings
- **Performance**: 3 issues (#23, #24, #25) — N+1 in assignment progress, redundant RPC, missing autoDispose
- **Cross-System Integrity**: 2 issues (#1, #2) — chapter/book/quiz XP idempotency gaps
- **Type Safety**: 3 issues (#27, #28, #29) — dynamic typing bypasses Dart type system

---

## Overview

The Book System is the core reading experience of Owlio. It manages the entire book lifecycle: creating/editing books and chapters (Admin), browsing/reading/tracking progress (Student), and monitoring reading stats (Teacher). The system encompasses library browsing, chapter-by-chapter reading with inline activities, content blocks with audio sync, book quizzes, reading progress tracking, offline download/caching, and assignment-based access gating.

## Data Model

### Tables

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `books` | id, title, slug, level (CEFR), genre, status (draft/published/archived), metadata, word_count, author, cover_image_url | Book catalog |
| `chapters` | id, book_id (FK CASCADE), title, order_index, content (nullable legacy), use_content_blocks (bool), audio_url, word_count, vocabulary (JSONB) | Chapter content |
| `content_blocks` | id, chapter_id (FK CASCADE), order_index, type (text/image/audio/activity), text, audio_url, word_timings (JSONB), activity_id | Structured chapter content (replaces legacy `content` field) |
| `inline_activities` | id, chapter_id (FK CASCADE), type (true_false/word_translation/find_words/matching), after_paragraph_index, content (JSONB), xp_reward | Mid-chapter mini games |
| `inline_activity_results` | id, user_id, inline_activity_id, is_correct, xp_earned | UNIQUE(user_id, inline_activity_id) for idempotency |
| `reading_progress` | id, user_id, book_id, chapter_id, current_page, is_completed, completion_percentage, completed_chapter_ids (array), quiz_passed, total_reading_time | UNIQUE(user_id, book_id) — one row per user-book pair |
| `daily_chapter_reads` | id, user_id, chapter_id, read_date | Tracks daily reading for quest progress. UNIQUE(user_id, chapter_id, read_date) |
| `book_quizzes` | id, book_id (FK CASCADE, UNIQUE), title, passing_score (default 70%), is_published | One quiz per book |
| `book_quiz_questions` | id, quiz_id (FK CASCADE), type (5 types), order_index, question, content (JSONB), points | Polymorphic question content |
| `book_quiz_results` | id, user_id, quiz_id, book_id, score, max_score, percentage, is_passing, attempt_number (trigger-set) | Multi-attempt quiz results |
| `activities` | id, chapter_id, type, order_index, questions (JSONB) | Legacy end-of-chapter activities (superseded by inline_activities) |
| `activity_results` | id, user_id, activity_id, score, max_score, answers | Legacy activity results |

### Key Relationships

```
books 1──* chapters 1──* content_blocks
                    1──* inline_activities 1──* inline_activity_results
                    1──* activities (legacy) 1──* activity_results (legacy)
books 1──1 book_quizzes 1──* book_quiz_questions
                        1──* book_quiz_results
books 1──* reading_progress (per user)
chapters 1──* daily_chapter_reads (per user per day)
```

## Surfaces

### Admin

- **Book CRUD**: Create/edit/delete books with metadata (title, level, genre, age group, word count, author, cover image). Status lifecycle: draft → published → archived.
- **Chapter Editor**: Create/edit chapters with order management. Two content modes: legacy `content` text field (deprecated) and structured `content_blocks` (current).
- **Content Block Editor**: Add/reorder/edit text, image, audio, and activity blocks within a chapter. Audio blocks support word-level timing data (JSONB).
- **JSON Import**: Bulk import books with chapters from JSON.
- **Quiz Editor**: Create quiz per book with 5 question types (multiple_choice, fill_blank, event_sequencing, matching, who_says_what). Set passing score (default 70%).
- **Inline Activity Editor**: Embed activities at specific paragraph positions within chapters (true_false, word_translation, find_words, matching).

### Student

1. **Library**: Browse published books filtered by category/level. Search. "Continue Reading" section shows in-progress books. Completed books shown with badge.
2. **Book Detail**: View book info, chapter list with sequential unlock (each chapter locks until previous is completed), progress percentage, download button.
3. **Reader**: Read chapter content (content blocks or legacy text). Inline activities appear between paragraphs. Audio playback with word-level sync. Reading time tracked automatically. Session XP counter.
4. **Chapter Completion**: Mark chapter complete → XP award (if first time) → assignment progress update → daily quest progress.
5. **Book Quiz**: Available only when all chapters read (100% progress) and quiz exists. Graded client-side. 70% pass threshold (configurable per quiz). Multi-attempt allowed. Passing sets `quiz_passed` and may complete the book.
6. **Offline Download**: Download book with all chapters, content blocks, activities, and quiz data to SQLite cache. Read offline with progress synced when back online.
7. **Book Access Control**: When a teacher creates an assignment with `lockLibrary: true`, only assigned books are accessible. Other books show lock overlay.

### Teacher

- **Reading Progress Report**: Per-book stats (total readers, completed, avg progress) across the school via `get_school_book_reading_stats` RPC.
- **Student Detail**: Per-student reading breakdown — completed chapters, total chapters, completion %, reading time, last read date via `get_student_progress_with_books` RPC.
- **Quiz Results**: Per-student quiz attempts — best score, total attempts, pass status via `get_student_quiz_results` RPC.

## Business Rules

1. **Sequential Chapter Unlock**: Chapters unlock sequentially — chapter N is locked until all chapters 0..N-1 are in `completed_chapter_ids`. Enforced client-side only (no server check).
2. **Chapter Completion XP**: First-time chapter completion awards `systemSettings.xpChapterComplete` (default 50 XP). Dedup is in-memory cache check only — no DB constraint.
3. **Book Completion XP**: When all chapters complete AND (no quiz OR quiz already passed), awards `systemSettings.xpBookComplete` (default 200 XP). Same in-memory dedup.
4. **Quiz Availability Gate**: Quiz is shown only when `completionPercentage >= 100% AND !isCompleted AND !quizPassed AND bookHasQuiz`.
5. **Quiz Passing**: Score >= `bookQuiz.passingScore` (default 70%). On pass: `reading_progress.quiz_passed = true`. If all chapters also complete: `reading_progress.is_completed = true`.
6. **Quiz XP**: `systemSettings.xpQuizPass` (default 20 XP) awarded on every passing attempt (no dedup — known bug).
7. **Quiz Attempt Number**: Set by DB trigger (`trg_set_quiz_attempt_number`), not client — prevents race conditions.
8. **Inline Activity XP**: Per-type values from `systemSettings` (xpInlineTrueFalse, xpInlineWordTranslation, xpInlineFindWords, xpInlineMatching). Dedup via UNIQUE constraint on `(user_id, inline_activity_id)`.
9. **Daily Chapter Read Logging**: `_logDailyChapterRead` inserts/upserts into `daily_chapter_reads` on each chapter completion. Fire-and-forget (errors swallowed). Used by daily quest `read_words` calculation.
10. **Reading Time Tracking**: `SaveReadingProgressUseCase` increments `total_reading_time` by `additionalReadingTime` (seconds). Guards against <= 0.
11. **Book Status Lifecycle**: draft → published → archived. Only `published` books visible to students. Controlled via `BookStatus` enum in owlio_shared.
12. **Content Block Migration Flag**: `chapter.use_content_blocks` determines rendering path. When `true`, reader uses `content_blocks` table. When `false`, uses legacy `content` text field. Both systems coexist.
13. **Offline Sync Strategy**: Cached repository uses cache-aside (read) + write-through (write). Offline writes set `isDirty: true` and queue pending actions (`award_xp`, `log_daily_read`). Quiz results do NOT queue offline XP.
14. **Assignment-Based Access**: When a book assignment has `contentConfig['lockLibrary'] = true`, library shows only assigned books. Unassigned books get lock overlay. Computed in `bookLockProvider`.
15. **Legacy Activity System**: `activities`/`activity_results` tables represent an older end-of-chapter system. Still wired and functional but superseded by `inline_activities`. `ActivityResult.isPassing` hardcodes 60% threshold (not configurable).

## Cross-System Interactions

### Chapter Completion Chain
```
Student reads chapter → ReaderScreen._handleNextChapter()
  → ChapterCompletionNotifier.markComplete()
    → MarkChapterCompleteUseCase → Repository: upsert reading_progress, log daily_chapter_reads
    → IF first-time completion:
      → UserController.addXP(xpChapterComplete) → award_xp_transaction RPC
        → Badge check: check_and_award_badges RPC
      → IF all chapters done AND (no quiz OR quiz passed):
        → UserController.addXP(xpBookComplete)
    → _updateAssignmentProgress()
      → For each matching book assignment: update progress %
      → IF 100%: CompleteAssignmentUseCase
      → For each unit assignment: CalculateUnitProgressUseCase RPC
    → Invalidate: readingProgressProvider, continueReadingProvider, dailyQuestProgressProvider
```

### Quiz Completion Chain
```
Student submits quiz → BookQuizController.submitQuiz()
  → SubmitQuizResultUseCase → Insert book_quiz_results
  → Repository._handleQuizPassed() → Update reading_progress (quiz_passed, is_completed)
  → IF passing:
    → UserController.addXP(xpQuizPass)
      → Badge check
  → Invalidate: bookQuizProvider, bestQuizResultProvider, readingProgressProvider
```

### Inline Activity Completion Chain
```
Student answers activity → handleInlineActivityCompletion()
  → SaveInlineActivityResultUseCase → Insert (UNIQUE constraint guards dedup)
  → IF new completion (not duplicate):
    → UserController.addXP(activityXp)
      → Badge check
    → IF has vocabulary words: AddWordsBatchUseCase
  → Invalidate: dailyQuestProgressProvider
```

### Daily Quest Integration
- `read_words` quest: SUM(chapters.word_count) from daily_chapter_reads WHERE read_date = today
- `correct_answers` quest: COUNT from inline_activity_results WHERE answered_at = today

### Streak
- NOT updated from any book activity. Streak updates only on app open via `_updateStreakIfNeeded()`.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No books in library | `_EmptyState` widget with icon and contextual message |
| No chapters for book | `Text('No chapters available')` — minimal |
| First chapter load (no progress) | Upsert creates `reading_progress` with `ON CONFLICT` |
| Re-completing already-completed chapter | `wasAlreadyCompleted` check prevents XP (in-memory only) |
| Quiz retake after passing | XP re-awarded (bug). `quiz_passed` not re-set (correct). |
| All chapters read, no quiz | Book marked complete, `xpBookComplete` awarded |
| All chapters read, quiz exists but not passed | Book NOT complete. Quiz unlocked. |
| Offline reading | Cached repository serves from SQLite. Progress writes queued as dirty. |
| Offline quiz submission | Result saved with `isDirty: true` but XP NOT queued for offline award. |
| Student deletes own reading progress | Possible via RLS `FOR ALL` policy (unintended). |
| Book deleted by admin | CASCADE deletes all chapters, activities, progress, quiz data. |
| Chapter deleted | Activities, content blocks CASCADE. `reading_progress.chapter_id` SET NULL. |
| `daily_chapter_reads` insert fails | Silently swallowed. Quest `read_words` won't progress for that day. |
| Category filter error in library | Silent `SizedBox(height: 80)` — no error feedback to user. |
| Provider failure (network error) | Returns empty list/null — user sees empty state, not error. |

## Test Scenarios

- [ ] Happy path: Browse library → open book → read chapters sequentially → complete book → earn XP
- [ ] Happy path: Read all chapters → take quiz → pass → book completes with quiz XP
- [ ] Happy path: Encounter inline activity during reading → answer correctly → earn XP
- [ ] Empty state: Fresh student sees library with "Start reading" prompts
- [ ] Empty state: Book with no chapters shows appropriate message
- [ ] Error state: Network failure during chapter load shows error scaffold with "Go Back"
- [ ] Boundary: Complete last chapter of a book with no quiz → verify book completion + XP
- [ ] Boundary: Complete last chapter of a book with quiz → verify book NOT complete until quiz passed
- [ ] Boundary: Retake passed quiz → verify XP is awarded again (current bug behavior)
- [ ] Boundary: Try to access locked chapter (not all previous completed) → verify lock enforced
- [ ] Cross-system: Chapter completion → verify assignment progress updated
- [ ] Cross-system: Chapter completion → verify daily quest `read_words` progress
- [ ] Cross-system: Inline activity → verify badge check fires via addXP
- [ ] Cross-system: Book access with `lockLibrary` assignment → verify only assigned books accessible
- [ ] Offline: Download book → go offline → read chapters → go online → verify sync
- [ ] Teacher: View reading progress report → verify per-book stats
- [ ] Teacher: View student detail → verify reading breakdown per book

## Key Files

### Domain
- `lib/domain/entities/book.dart` — Book, Chapter, ReadingProgress entities
- `lib/domain/entities/book_quiz.dart` — BookQuiz, 5 question content types, BookQuizResult
- `lib/domain/entities/content/content_block.dart` — ContentBlock, WordTiming
- `lib/domain/repositories/book_repository.dart` — 20-method repository interface

### Data
- `lib/data/repositories/supabase/supabase_book_repository.dart` — Primary data access
- `lib/data/repositories/cached/cached_book_repository.dart` — Offline-first cache wrapper
- `lib/data/repositories/supabase/supabase_book_quiz_repository.dart` — Quiz + `_handleQuizPassed`

### Presentation
- `lib/presentation/providers/book_provider.dart` — `ChapterCompletionNotifier` (core cross-system orchestrator)
- `lib/presentation/providers/reader_provider.dart` — Reader state + inline activity completion
- `lib/presentation/providers/book_quiz_provider.dart` — `BookQuizController`
- `lib/presentation/screens/library/library_screen.dart` — Library browsing
- `lib/presentation/screens/reader/reader_screen.dart` — Reading session
- `lib/presentation/screens/quiz/book_quiz_screen.dart` — Quiz flow

### Admin
- `owlio_admin/lib/features/books/screens/book_list_screen.dart` — Book management
- `owlio_admin/lib/features/books/screens/book_edit_screen.dart` — Book editing
- `owlio_admin/lib/features/books/screens/chapter_edit_screen.dart` — Chapter editing

### Database
- `supabase/migrations/20260131000003_create_content_tables.sql` — books, chapters, inline_activities
- `supabase/migrations/20260131000005_create_progress_tables.sql` — reading_progress, inline_activity_results
- `supabase/migrations/20260211000001_create_book_quiz_tables.sql` — Quiz tables
- `supabase/migrations/20260211000003_quiz_rpc_functions.sql` — Quiz RPCs

## Known Issues & Tech Debt

1. **Chapter/book XP idempotency gap** (#1) — In-memory only. Should pass `source_id` (e.g., `chapter:{chapterId}`) to `award_xp_transaction` for DB-level dedup.
2. **Quiz XP re-award on retakes** (#2) — `submitQuiz` should check `quiz_passed` before awarding XP, or use `source_id`.
3. **Two competing activity systems** — Legacy `activities`/`activity_results` coexist with `inline_activities`/`inline_activity_results`. Legacy system should be deprecated once migration is complete.
4. **`author` column not in model** (#26) — `books.author` exists in DB but `BookModel` reads from `metadata['author']`. Should be a typed field.
5. **Content block migration** — `use_content_blocks` flag enables gradual migration. Old chapters use `content` text; new chapters use `content_blocks`. Both rendering paths must be maintained until all chapters are migrated.
6. **`reading_progress` DELETE policy** (#9) — Students can delete their own progress via the `FOR ALL` RLS policy. Should be restricted to SELECT/INSERT/UPDATE.
7. **Offline quiz XP** (#13 in business rules) — Quiz pass offline does not queue `award_xp` action. XP is lost if the user doesn't retake online.
8. **`_updateAssignmentProgress` inefficiency** (#23) — Runs RPC for every unit assignment on every chapter completion. Should filter to relevant units only.
``