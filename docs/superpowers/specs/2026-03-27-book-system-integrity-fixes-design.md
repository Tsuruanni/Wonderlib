# Book System Integrity Fixes

Fixes for data integrity bugs, architecture violations, and error handling gaps identified in the Book System audit (`docs/specs/01-book-system.md`).

**Scope:** Findings #1-#9, #23-#25, #30-#31 (groups A+B+C). Dead code and cosmetic cleanup (group D: #11-#22, #26-#29, #32-#38) deferred to a separate session.

**Approach:** DB-first, then client. Three phases executed sequentially.

---

## Phase 1: Data Integrity (DB Migrations + addXP Chain)

### 1.1 XP Idempotency — source_id Support (#1, #2)

**Problem:** `award_xp_transaction` RPC supports `source_id` for idempotency, but the entire Flutter call chain hardcodes it to `null`. Chapter completion, book completion, and quiz pass XP have zero DB-level dedup — only an in-memory cache check that is vulnerable to race conditions and stale state.

**Additionally:** Quiz XP is awarded on every passing attempt with no dedup at all. A student can retake a passed quiz unlimited times for unlimited XP.

**Fix — Full chain update:**

```
UserController.addXP(amount, {source, sourceId})
    → AddXPParams(userId, amount, source, sourceId)
    → AddXPUseCase → UserRepository.addXP(userId, amount, source, sourceId)
    → RPC: p_source=source, p_source_id=sourceId
```

**Files to modify:**
- `lib/presentation/providers/user_provider.dart` — `addXP` signature: add optional `source` and `sourceId` params
- `lib/domain/usecases/user/add_xp_usecase.dart` — `AddXPParams`: add `source` and `sourceId` fields
- `lib/domain/repositories/user_repository.dart` — `addXP` interface: add `source` and `sourceId` params
- `lib/data/repositories/supabase/supabase_user_repository.dart` — pass `source` and `sourceId` to RPC instead of hardcoded `'manual'` / `null`

**Defaults:** `source = 'manual'`, `sourceId = null` — backward compatible, callers outside scope don't break.

**Callers to update with source_id:**

| Caller | File | source | sourceId |
|--------|------|--------|----------|
| Chapter completion XP | `book_provider.dart` (`ChapterCompletionNotifier.markComplete`) | `'chapter_complete'` | `chapterId` |
| Book completion XP | `book_provider.dart` (`ChapterCompletionNotifier.markComplete`) | `'book_complete'` | `bookId` |
| Quiz pass XP | `book_quiz_provider.dart` (`BookQuizController.submitQuiz`) | `'quiz_pass'` | `quizId` |
| Inline activity XP | `reader_provider.dart` (`handleInlineActivityCompletion`) | `'inline_activity'` | `activityId` |

**Idempotency behavior:** When `source_id` is non-null, the RPC checks `xp_logs(user_id, source, source_id)`. If a match exists, it returns current state without awarding XP. This means:
- Same chapter completed twice → second call is a no-op
- Same quiz passed again → no additional XP
- Same inline activity → already protected by DB UNIQUE, now also by XP-level dedup

**Audit trail benefit:** `xp_logs` will now show the exact source and linked entity for every XP award, enabling per-channel analytics and anomaly detection.

### 1.2 reading_progress RLS Fix (#9)

**Problem:** `reading_progress` has a `FOR ALL` RLS policy that includes DELETE. A student can delete their own reading progress rows via direct API access.

**Fix — New migration:**

```sql
DROP POLICY "Users can manage own reading progress" ON reading_progress;

CREATE POLICY "Users can read own reading progress"
    ON reading_progress FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can insert own reading progress"
    ON reading_progress FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own reading progress"
    ON reading_progress FOR UPDATE
    USING (user_id = auth.uid());

-- No DELETE policy for students
```

Existing teacher SELECT policy (separate migration) is not affected.

### 1.3 Finding #10 — Already Fixed (False Positive)

`book_quizzes` RLS `head_teacher` → `head` was already corrected in migration `20260213000001_fix_rls_policies.sql`. No action needed.

---

## Phase 2: Architecture Refactors

### 2.1 GradeBookQuizUseCase (#3)

**Problem:** Quiz grading logic (`_gradeQuestion`, `_serializeAnswer`, score accumulation loop) lives in `BookQuizScreen` widget. Cannot be unit tested without widget test, cannot be reused.

**Fix:** Create `GradeBookQuizUseCase` in domain layer.

**New file:** `lib/domain/usecases/book_quiz/grade_book_quiz_usecase.dart`

```dart
class GradeBookQuizParams {
  final BookQuiz quiz;
  final Map<String, dynamic> answers;
}

class GradeQuizResult {
  final double totalScore;
  final double maxScore;
  final double percentage;
  final bool isPassing;
  final Map<String, dynamic> answersJson; // per-question result for submission
}

class GradeBookQuizUseCase {
  GradeQuizResult call(GradeBookQuizParams params);
}
```

**Modifications:**
- `book_quiz_screen.dart` — remove `_gradeQuestion`, `_serializeAnswer`, `_isAnswerValid`, score loop. Replace with `ref.read(gradeBookQuizUseCaseProvider)(params)`.
- `usecase_providers.dart` — register `gradeBookQuizUseCaseProvider`.

### 2.2 HandleQuizPassedUseCase (#7, #16)

**Problem:** `_handleQuizPassed` in `SupabaseBookQuizRepository` contains multi-step business logic (fetch progress → fetch chapters → compute completion → update progress). Same "is book complete?" logic is partially duplicated in `SupabaseBookRepository.markChapterComplete`.

**Fix:** Create `HandleBookCompletionUseCase` — single source of truth for "is this book complete?".

**New file:** `lib/domain/usecases/reading/handle_book_completion_usecase.dart`

```dart
class HandleBookCompletionParams {
  final String userId;
  final String bookId;
  // Caller provides the trigger context
  final bool quizJustPassed; // true when called from quiz flow
}

class HandleBookCompletionUseCase {
  // Uses BookRepository to:
  // 1. getReadingProgress
  // 2. getChapters (count)
  // 3. bookHasQuiz
  // 4. Decide: allChaptersComplete && (noQuiz || quizPassed) → complete
  // 5. updateReadingProgress if status changed
  // Returns: updated ReadingProgress
}
```

**Layer boundary:** The UseCase handles the decision + reading_progress update. XP award stays in the presentation layer (providers) because `addXP` triggers badge checks and level-up events that are UI concerns.

**Modifications:**
- `supabase_book_quiz_repository.dart` — remove `_handleQuizPassed`. Repository only inserts quiz result.
- `supabase_book_repository.dart` — `markChapterComplete` simplifies: updates progress (completed_chapter_ids, completion_percentage), logs daily read. Does NOT decide book completion.
- `book_provider.dart` (`ChapterCompletionNotifier`) — after `markChapterComplete`, calls `HandleBookCompletionUseCase` to check if book is now complete. If yes and `!wasAlreadyCompleted`, awards XP.
- `book_quiz_provider.dart` (`BookQuizController`) — after quiz submission, calls `HandleBookCompletionUseCase(quizJustPassed: true)`. If book is now complete, awards XP.

This eliminates the redundant `book_has_quiz` RPC call (#24) as a side effect — the UseCase calls it once.

### 2.3 CompleteInlineActivityUseCase (#4)

**Problem:** `handleInlineActivityCompletion` is a 90-line free function taking `WidgetRef`. Mixes domain logic (DB save, XP award, vocabulary add) with UI concerns (provider invalidation, session counter).

**Fix:** Split into UseCase + thin presentation wrapper.

**New file:** `lib/domain/usecases/activity/complete_inline_activity_usecase.dart`

```dart
class CompleteInlineActivityParams {
  final String userId;
  final String activityId;
  final bool isCorrect;
  final int xpEarned;
  final List<String> wordsLearned;
}

class CompleteInlineActivityResult {
  final bool isNewCompletion;
  final int xpAwarded;
  final int wordsAdded;
}

class CompleteInlineActivityUseCase {
  // 1. SaveInlineActivityResult (DB UNIQUE dedup)
  // 2. If words: AddWordsBatch
  // Returns result — presentation layer handles XP award + provider invalidation
  // (XP award stays in presentation because addXP triggers badge checks and level-up UI events)
}
```

**Modifications:**
- `reader_provider.dart` — `handleInlineActivityCompletion` becomes a thin wrapper: calls UseCase, then handles provider invalidations + session XP counter + onComplete callback.
- `usecase_providers.dart` — register provider.

### 2.4 Chapter Lock Status Provider (#5)

**Problem:** Chapter lock algorithm (for-loop checking all previous chapters) lives in `BookDetailScreen.build()`.

**Fix:** New computed provider.

**New provider in `book_provider.dart`:**

```dart
final chaptersWithLockStatusProvider = Provider.family<List<ChapterWithLockStatus>, String>((ref, bookId) {
  final chapters = ref.watch(chaptersProvider(bookId)).valueOrNull ?? [];
  final progress = ref.watch(readingProgressProvider(bookId)).valueOrNull;
  final completedIds = progress?.completedChapterIds ?? [];

  return chapters.indexed.map((e) {
    final (index, chapter) = e;
    final isLocked = index > 0 && chapters.take(index).any((c) => !completedIds.contains(c.id));
    return ChapterWithLockStatus(chapter: chapter, isLocked: isLocked, isCompleted: completedIds.contains(chapter.id));
  }).toList();
});
```

**Modifications:**
- `book_detail_screen.dart` — remove inline lock logic, watch `chaptersWithLockStatusProvider(bookId)` instead.

### 2.5 Book Access — Typed Entity Properties (#6)

**Problem:** `bookLockProvider` accesses `assignment.contentConfig['lockLibrary']` and `assignment.contentConfig['bookId']` as dynamic map lookups. Type-unsafe.

**Fix:** Add typed getters to `StudentAssignment` entity:

```dart
// In StudentAssignment entity
bool get hasLibraryLock => contentConfig['lockLibrary'] == true;
String? get lockedBookId => contentConfig['bookId'] as String?;
```

**Modifications:**
- `student_assignment.dart` (entity) — add getters.
- `book_access_provider.dart` — replace dynamic map access with typed getters.

---

## Phase 3: Error Handling / UX / Performance

### 3.1 Provider Error Propagation (#8)

**Problem:** All book FutureProviders return empty list/null on failure. Screens never see error state.

**Fix:** Change all book providers from:
```dart
return result.fold((failure) => [], (books) => books);
```
to:
```dart
return result.fold((failure) => throw Exception(failure.message), (books) => books);
```

**Affected providers in `book_provider.dart`:** `booksProvider`, `bookByIdProvider`, `bookSearchProvider`, `recommendedBooksProvider`, `continueReadingProvider`, `chaptersProvider`, `readingProgressProvider`, `completedBookIdsProvider`.

**Affected providers in other files:** `bookHasQuizProvider`, `bookQuizProvider`, `bestQuizResultProvider` in `book_quiz_provider.dart`.

**Screen updates:** Verify that all screens using these providers have proper `.when(error: ...)` handling. Replace raw `Text('Error: $error')` with user-friendly error widget + retry.

### 3.2 Unit Assignment Filtering (#23)

**Problem:** `_updateAssignmentProgress` calls `CalculateUnitProgressUseCase` RPC for every unit assignment on every chapter completion, regardless of relevance.

**Fix:** Before calling `CalculateUnitProgressUseCase`, check if the current book is actually an item in that unit. Either:
- (a) Client-side: check `assignment.contentConfig` for book reference — only call RPC if match
- (b) Server-side: RPC already does this check internally but still costs a network round-trip. Client-side pre-filter is cheaper.

Option (a) preferred — skip the RPC entirely for non-matching units.

### 3.3 Redundant book_has_quiz Call (#24)

**Resolved by Phase 2.2.** `HandleBookCompletionUseCase` calls `bookHasQuiz` once. Neither `markChapterComplete` nor the notifier call it independently.

### 3.4 autoDispose on FutureProvider.family (#25)

**Problem:** Book providers without `autoDispose` accumulate memory as user browses books.

**Fix:** Add `.autoDispose` to these providers:
- `booksProvider`
- `bookByIdProvider`
- `bookSearchProvider`
- `chaptersProvider`
- `readingProgressProvider`
- `completedBookIdsProvider`
- `completedInlineActivitiesProvider`
- `contentBlocksProvider`
- `chapterUsesContentBlocksProvider`

**Impact:** Cached repository ensures re-fetch is fast (served from SQLite). No UX regression.

### 3.5 Error State Widgets (#30, #31)

**Problem:** Library categories error → silent empty SizedBox. Book screens → raw `Text('Error: $error')`.

**Fix:** Replace with user-friendly error widget (icon + message + retry button). Check if project has a shared `ErrorStateWidget` — if yes, use it. If not, create a minimal one.

**Affected screens:**
- `library_screen.dart` — categories error, book list error
- `book_detail_screen.dart` — book error, chapters error

---

## Out of Scope (Deferred)

### Group D — Cleanup (separate session)
Findings #11-#22, #26-#29, #32-#38: dead code removal, duplicate code cleanup, type safety fixes, schema drift, admin Turkish text, cosmetic improvements. Also includes deep audit of admin panel features not covered in this plan: JSON import logic/validation, chapter editor, content block editor.

### XP Balancing
Quiz-less books award 200 XP completion bonus; quiz books award only 20 XP quiz pass. This imbalance is noted but not addressed — requires a dedicated balancing session.

---

## Risk Notes

- **Phase 1 DB migrations are irreversible** on remote Supabase. Always `--dry-run` first.
- **Phase 1 addXP chain** is backward-compatible (defaults to `'manual'` / `null`). Callers outside book system (vocab, daily review) continue working unchanged.
- **Phase 2 architecture refactors** change no business rules — same behavior, different location. Risk is regressions from wiring changes.
- **Phase 3 error propagation** will surface errors that were previously hidden. Screens must be verified to have proper error handling before this change ships.

## Verification

After all phases:
- `dart analyze lib/` must pass
- Manual test: complete a chapter → verify XP awarded once only, `xp_logs` shows correct source/source_id
- Manual test: retake passed quiz → verify no additional XP
- Manual test: browse library offline → verify error state shown (not empty state)
- Manual test: browse 10+ books → verify memory doesn't grow (provider autoDispose)
