# Book Quiz

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Data Integrity | `updateReadingProgress` in `supabase_book_repository.dart` omits `quiz_passed` from the upsert data map — column stays `false` in DB forever. `HandleBookCompletionUseCase` sets `quizPassed: true` via `copyWith` but the field is silently dropped at persistence. `is_completed` IS written, so books appear complete locally and on re-fetch, but the `quiz_passed` column is dead for any future query or reporting. | High | TODO |
| 2 | Security | `get_best_book_quiz_result` RPC is `SECURITY DEFINER` with no authorization check — any authenticated user can pass any `p_user_id` and retrieve another student's best quiz score. Unlike `get_student_quiz_results` which has a school-membership check. | High | TODO |
| 3 | Edge Case | Published quiz with 0 questions soft-locks the student: `bookHasQuizProvider` returns `true` (quiz exists, published), `isQuizReadyProvider` returns `true` (quiz not passed), "Take quiz" CTA shown — but `BookQuizScreen` renders "No quiz available" with only a "Go Back" button. Student cannot complete the book. | High | TODO |
| 4 | Dead Code | `BookQuizProgressBar.answeredIndices` parameter accepted in constructor but never used — progress is computed from `(currentIndex + 1) / totalQuestions`. The `Set<int>` is built and passed from `BookQuizScreen` (lines 207-211) for nothing. | Low | TODO |
| 5 | Dead Code | `_goToNextPage` condition `_currentPage < 999` always evaluates to `true`, making the first clause (`_currentPage < (_pageController.page?.round() ?? 0) + 1`) dead. `PageController.nextPage` beyond last page is a Flutter no-op so no visible bug, but logic is nonsensical. | Low | TODO |
| 6 | Dead Code | `BookQuizController.submitQuiz` never receives `timeSpent` — `BookQuizScreen._submitQuiz` does not measure elapsed time. The `time_spent` column is always `null` in the database. | Low | TODO |
| 7 | Dead Code | `BookQuizModel.fromEntity` / `BookQuizQuestionModel.fromEntity` never called in the main app — only `BookQuizResultModel.fromEntity` is used (for `toInsertJson()`). Untested code paths. | Low | TODO |
| 8 | Code Quality | `BookQuizQuestionModel._parseType` and `_typeToString` duplicate logic already on `BookQuizQuestionType.fromDbValue()` / `.dbValue` from owlio_shared. Two 5-case switch statements that could diverge from the shared enum. | Medium | TODO |
| 9 | Code Quality | Admin quiz editor uses raw string literals (`'multiple_choice'`, `'fill_blank'`) in switch cases instead of `BookQuizQuestionType.x.dbValue`. | Low | TODO |
| 10 | Code Quality | Hard-coded color literals `Color(0xFF58CC02)` and `Color(0xFFFF4B4B)` in `book_quiz_result_card.dart` — `AppColors.primary` already defines `0xFF58CC02`. | Low | TODO |
| 11 | Architecture | Admin quiz editor (`book_quiz_edit_screen.dart`, `quiz_question_edit_screen.dart`) has all user-facing labels in Turkish: "Kitap Quizini Düzenle", "Geçme Puanı (%)", "Çoktan Seçmeli", etc. Violates CLAUDE.md "UI in English" rule. | Medium | TODO |
| 12 | Performance | `HandleBookCompletionUseCase` makes 3 sequential async calls (`getReadingProgress`, `getChapters`, `bookHasQuiz`) — last two are independent and could be `Future.wait`-ed. | Low | Deferred |
| 13 | Performance | Missing `(user_id, book_id)` composite index on `book_quiz_results` — `getUserQuizResults` and `get_best_book_quiz_result` both filter by both columns but only individual column indexes exist. | Low | TODO |
| 14 | Edge Case | Event sequencing registers shuffled initial order as answer via `addPostFrameCallback` — if student never touches the question and submits, it counts as "answered" with a likely-wrong order. | Low | Accepted |
| 15 | Edge Case | Cleared `fillBlank` field calls `onAnswer('')` — empty string satisfies `allAnswered` check (non-null) but always grades wrong. Student may not realize they need to type before proceeding. | Low | Accepted |
| 16 | Dead Code | Commented-out instruction UI blocks in `book_quiz_matching.dart`, `book_quiz_who_says_what.dart`, `book_quiz_screen.dart` — `quiz.instructions` field stored in DB but never shown to students. | Low | Accepted |

### Checklist Result

- **Architecture Compliance**: PASS — Clean architecture fully respected in main app. Screen → Provider → UseCase → Repository chain intact. No JSON in entities. `DbTables.bookQuizzes` / `DbTables.bookQuizResults` / `DbTables.bookQuizQuestions` used. `BookQuizQuestionType` enum from owlio_shared. Admin panel uses direct Supabase (accepted pattern).
- **Code Quality**: 3 issues — duplicate type parsing (#8), raw string switch cases in admin (#9), hard-coded colors (#10). Turkish admin labels (#11).
- **Dead Code**: 4 issues — unused `answeredIndices` (#4), dead navigation condition (#5), unused `timeSpent` (#6), unused `fromEntity` constructors (#7), commented-out instructions (#16).
- **Database & Security**: 2 issues — `quiz_passed` never written (#1), `get_best_book_quiz_result` missing auth check (#2). RLS policies correct. Attempt number trigger + UNIQUE constraint enforce idempotency. Cascading deletes handled.
- **Edge Cases & UX**: 1 critical — 0-question published quiz soft-lock (#3). 2 minor accepted (#14, #15). Loading/empty/error states handled in `BookQuizScreen`.
- **Performance**: 2 low issues — sequential calls (#12, deferred), missing composite index (#13).
- **Cross-System Integrity**: PASS — XP via `userControllerProvider.addXP()` with `source='quiz_pass', sourceId=quizId` (idempotent). Badge check via `addXP`. `HandleBookCompletionUseCase` called on passing. Providers invalidated: `bestQuizResultProvider`, `readingProgressProvider`, `completedBookIdsProvider`, `continueReadingProvider`, `isQuizReadyProvider`. Streak not updated (correct — app-open only).

---

## Overview

Book Quiz is an end-of-book assessment system. Each book can have one quiz with multiple question types. Students must pass the quiz (default ≥70%) to complete quiz-gated books. Quizzes support unlimited retakes — best score counts for teacher reporting, XP is awarded only on the first passing attempt. Admins create quizzes and questions through the admin panel; teachers view per-student quiz results.

## Data Model

### Tables

| Table | Key Columns | Purpose |
|-------|-------------|---------|
| `book_quizzes` | id, book_id (FK CASCADE, UNIQUE), title, instructions, passing_score (DECIMAL, default 70.00), total_points, is_published (BOOLEAN) | One quiz per book. Must be published to be visible to students. |
| `book_quiz_questions` | id, quiz_id (FK CASCADE), type (CHECK: multiple_choice / fill_blank / event_sequencing / matching / who_says_what), order_index, question (TEXT), content (JSONB), explanation, points (default 1), UNIQUE(quiz_id, order_index) | Polymorphic questions. Content JSONB structure varies by type. |
| `book_quiz_results` | id, user_id (FK CASCADE), quiz_id (FK CASCADE), book_id (FK CASCADE), score, max_score, percentage, is_passing, answers (JSONB), time_spent, attempt_number (trigger-set), completed_at, UNIQUE(user_id, quiz_id, attempt_number) | Student attempts. Attempt number auto-incremented by DB trigger. |
| `reading_progress` | quiz_passed (BOOLEAN, default false) | Added column — tracks whether quiz was passed for book completion gating. |

### Content JSONB Structure per Type

**multiple_choice:**
```json
{"options": ["A", "B", "C", "D"], "correct_answer": "B"}
```

**fill_blank:**
```json
{"sentence": "The ___ ran away.", "correct_answer": "fox", "accept_alternatives": ["Fox"]}
```

**event_sequencing:**
```json
{"events": ["First event", "Second event", "Third event"], "correct_order": [0, 1, 2]}
```

**matching:**
```json
{"left": ["word1", "word2"], "right": ["match1", "match2"], "correct_pairs": {"0": "1", "1": "0"}}
```

**who_says_what:**
```json
{"characters": ["Alice", "Bob"], "quotes": ["Hello", "Goodbye"], "correct_pairs": {"0": "0", "1": "1"}}
```

### Key Relationships

- `book_quizzes.book_id` → `books.id` (CASCADE, UNIQUE) — one quiz per book, deleting book removes quiz
- `book_quiz_questions.quiz_id` → `book_quizzes.id` (CASCADE) — deleting quiz removes all questions
- `book_quiz_results.user_id` → `profiles.id` (CASCADE) — deleting user removes their results
- `book_quiz_results.quiz_id` → `book_quizzes.id` (CASCADE) — deleting quiz removes all results
- `book_quiz_results.book_id` → `books.id` (CASCADE) — redundant FK for query convenience

## Surfaces

### Admin

- **Quiz Editor** (`owlio_admin/.../book_quiz_edit_screen.dart`): Create/edit quiz for a book (title, instructions, passing score). Manage questions with drag-and-drop reordering. Save always sets `is_published = true`.
- **Question Editor** (`owlio_admin/.../quiz_question_edit_screen.dart`): Per-question CRUD for all 5 types. Content form adapts per type (options editor for multiple_choice, sentence+answer for fill_blank, event list for sequencing, pair editor for matching/who_says_what).
- **Book Edit Screen**: Shows quiz summary widget with link to quiz editor.
- Admin queries Supabase directly (no Clean Architecture — accepted pattern for admin panel).

### Student

**User flow:**
1. Student reads all chapters of a book
2. If book has a published quiz: "Take Quiz" CTA appears in chapter completion widget and book detail screen
3. `isQuizReadyProvider` shows a badge on library/home book cards when quiz is available and not yet passed
4. Student opens quiz → `BookQuizScreen` loads quiz and questions
5. Questions rendered as swipeable pages via `PageController`
6. Student answers each question (type-specific widgets: tap option, type text, drag to reorder, tap to match)
7. "Submit" button enabled when all questions answered
8. `GradeBookQuizUseCase` grades locally (pure function, no server call for grading)
9. Result card shown: score, percentage, pass/fail status
10. If passing (≥ `quiz.passingScore`):
    - `BookQuizController.submitQuiz` → inserts result to DB
    - XP awarded via `addXP(xpQuizPass, source: 'quiz_pass', sourceId: quizId)`
    - `HandleBookCompletionUseCase` checks all chapters + quiz → marks book completed
11. If failing: result saved, student can retake ("Try Again" button)
12. Unlimited retakes allowed — best score counts

### Teacher

- **Student Detail Screen** (`student_detail_screen.dart`): Shows quiz results per student via `studentQuizResultsProvider` which calls `get_student_quiz_results` RPC. Displays best score per book, total attempts, first/best attempt dates, pass/fail status.

## Business Rules

1. **One quiz per book** — enforced by UNIQUE(book_id) on `book_quizzes`. Creating a second quiz for the same book fails at DB level.
2. **Passing threshold** — stored per-quiz in `book_quizzes.passing_score` (default 70%). Check is `percentage >= passingScore` (inclusive).
3. **XP award** — `system_settings.xp_quiz_pass` (default: 20 XP). Awarded only once per quiz via idempotency key `(source='quiz_pass', sourceId=quizId)` in `award_xp_transaction` RPC. Retaking a passed quiz does NOT award additional XP.
4. **Coin award** — equal to XP amount. `award_xp_transaction` atomically awards both XP and coins.
5. **Attempt numbering** — fully server-side via `trg_set_quiz_attempt_number` DB trigger. Client-side `attemptNumber` field is excluded from `toInsertJson()`. UNIQUE(user_id, quiz_id, attempt_number) prevents concurrent duplicates.
6. **Multi-attempt policy** — unlimited retakes. All attempts stored. Best score used for teacher reporting (`get_student_quiz_results` uses `DISTINCT ON ... ORDER BY percentage DESC`).
7. **Quiz gates book completion** — `HandleBookCompletionUseCase` checks: if book has a published quiz AND quiz not yet passed → book cannot be marked `is_completed = true`. Without a quiz, all-chapters-read is sufficient.
8. **Grading is client-side** — `GradeBookQuizUseCase` is a pure function. No server-side grading. Answers JSONB stored in `book_quiz_results` for auditability.
9. **Question grading rules:**
   - `multiple_choice`: exact string match against `correctAnswer`
   - `fill_blank`: case-insensitive, trimmed match against `correctAnswer` OR any item in `acceptAlternatives`
   - `event_sequencing`: index-by-index comparison — ALL positions must match (no partial credit)
   - `matching` / `who_says_what`: all pairs must match exactly AND map lengths must be equal
10. **Points per question** — stored as `int` (default 1). Quiz `total_points` is the sum, updated on admin save.
11. **Publishing** — admin save always sets `is_published = true`. There is no draft workflow visible to students. Unpublished quizzes are invisible to students via RLS (`is_published = true` SELECT policy).

## Cross-System Interactions

### Quiz Completion Chain (Passing)
```
Student submits quiz with passing score
  → GradeBookQuizUseCase: local grading (pure function)
  → BookQuizController.submitQuiz:
    → SubmitQuizResultUseCase → book_quiz_results INSERT
      → DB trigger: set attempt_number atomically
    → addXP(xpQuizPass, source: 'quiz_pass', sourceId: quizId)
      → award_xp_transaction RPC:
        → xp_logs INSERT (idempotent on source+sourceId)
        → profiles.xp_total += xp, profiles.coins += xp
        → CheckAndAwardBadgesUseCase (auto badge check)
    → HandleBookCompletionUseCase(quizJustPassed: true):
      → getReadingProgress → getChapters → bookHasQuiz
      → IF all chapters complete AND quiz passed:
        → updateReadingProgress(isCompleted: true)
    → Invalidate: bestQuizResultProvider, readingProgressProvider,
                  completedBookIdsProvider, continueReadingProvider,
                  isQuizReadyProvider
```

### Quiz Completion Chain (Failing)
```
Student submits quiz with failing score
  → GradeBookQuizUseCase: local grading
  → BookQuizController.submitQuiz:
    → SubmitQuizResultUseCase → book_quiz_results INSERT
    → NO XP (only on passing)
    → NO book completion check
    → Invalidate: bestQuizResultProvider
```

### What This System Does NOT Trigger
- **Streak**: Updated on app open only (`_updateStreakIfNeeded`), not per-quiz
- **Assignment progress**: Not directly updated by quiz submission. Reading progress invalidation may indirectly update book-type assignments via their watchers.
- **Daily quest**: No direct quest progress from quiz — quizzes are not counted as "correct answers" or "chapters read"
- **Vocabulary**: No vocabulary integration in quizzes

## Edge Cases

| Scenario | Current Behavior |
|----------|-----------------|
| Book with no quiz | `bookHasQuizProvider` returns `false`. Book completes when all chapters read. No quiz CTA shown. |
| Published quiz with 0 questions | **BUG (#3)**: `isQuizReadyProvider` returns `true` but quiz screen shows "No quiz available". Student cannot complete the book. |
| Student retakes passed quiz | New attempt saved with incremented `attempt_number`. No additional XP (idempotent on `quizId`). Best score still counts. |
| Submit timeout + retry | Retry creates a new DB row with next `attempt_number`. Not idempotent client-side, but each attempt is valid. |
| Offline quiz attempt | `CachedBookQuizRepository` saves result to SQLite with `isDirty: true`. Synced on reconnect. XP awarded optimistically. |
| Offline quiz load | Cache returns quiz if previously loaded. Cold-cache offline: `NetworkFailure`, quiz unavailable. |
| `quiz_passed` column | **BUG (#1)**: Never written to DB. `is_completed` IS written, so book appears complete. Column is effectively dead. |
| Empty fill_blank answer | Empty string satisfies `allAnswered` check but grades as wrong. Student can submit without typing. |
| Event sequencing untouched | Shuffled initial order registered as answer. Always grades (likely wrong). |

## Test Scenarios

- [ ] Happy path: Complete quiz with ≥70% score — XP awarded, book marked complete, quiz CTA removed
- [ ] Failing score: Complete quiz with <70% — result saved, no XP, "Try Again" shown, book not completed
- [ ] Multiple attempts: Fail then pass — both attempts stored, XP awarded only on first pass
- [ ] XP idempotency: Pass same quiz twice — only one XP award (check `xp_logs` for duplicate)
- [ ] All 5 question types: Verify each type grades correctly (correct and incorrect answers)
- [ ] fill_blank alternatives: Answer with an alternative spelling — graded correct
- [ ] fill_blank case-insensitive: Answer "Fox" when correct is "fox" — graded correct
- [ ] event_sequencing partial: Get 2 of 3 positions correct — graded wrong (all-or-nothing)
- [ ] matching incomplete: Match 2 of 3 pairs — cannot submit (allAnswered check)
- [ ] Zero-question quiz: Publish quiz with no questions — verify student not soft-locked
- [ ] Book without quiz: Read all chapters — book completes without quiz
- [ ] Quiz gates completion: Read all chapters but fail quiz — book NOT marked complete
- [ ] Teacher view: Teacher sees student's best quiz scores per book with attempt counts
- [ ] Offline: Take quiz offline — result cached, synced on reconnect
- [ ] Badge check: Verify badge conditions evaluated after quiz XP award
- [ ] Provider invalidation: After passing quiz, library/home screens update (no stale "quiz ready" badge)

## Key Files

| Surface | File | Purpose |
|---------|------|---------|
| Shared | `packages/owlio_shared/lib/src/enums/book_quiz_question_type.dart` | `BookQuizQuestionType` enum (5 values) with `dbValue`/`fromDbValue` |
| Shared | `packages/owlio_shared/lib/src/constants/tables.dart` | `DbTables.bookQuizzes`, `.bookQuizQuestions`, `.bookQuizResults` |
| Shared | `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | `RpcFunctions.bookHasQuiz`, `.getBestBookQuizResult`, `.getStudentQuizResults` |
| Domain | `lib/domain/entities/book_quiz.dart` | `BookQuiz`, `BookQuizQuestion`, `BookQuizResult`, polymorphic content classes |
| Domain | `lib/domain/usecases/book_quiz/grade_book_quiz_usecase.dart` | Pure local grading logic for all 5 types |
| Domain | `lib/domain/usecases/reading/handle_book_completion_usecase.dart` | Quiz-gates book completion |
| Data | `lib/data/repositories/supabase/supabase_book_quiz_repository.dart` | Supabase implementation (6 methods) |
| Data | `lib/data/repositories/cached/cached_book_quiz_repository.dart` | Cache-aside + write-through |
| Presentation | `lib/presentation/providers/book_quiz_provider.dart` | `BookQuizController` + 5 providers |
| Presentation | `lib/presentation/screens/quiz/book_quiz_screen.dart` | Full quiz experience (PageView) |
| Presentation | `lib/presentation/widgets/book_quiz/` | 5 question type widgets + progress bar + result card |
| Admin | `owlio_admin/lib/features/quizzes/screens/book_quiz_edit_screen.dart` | Quiz CRUD + question reorder |
| Admin | `owlio_admin/lib/features/quizzes/screens/quiz_question_edit_screen.dart` | Per-question CRUD for all 5 types |
| Teacher | `lib/presentation/screens/teacher/student_detail_screen.dart` | Student quiz results display |
| Migration | `supabase/migrations/20260211000001_create_book_quiz_tables.sql` | Tables, RLS, indexes |
| Migration | `supabase/migrations/20260211000003_quiz_rpc_functions.sql` | 3 RPC functions |
| Migration | `supabase/migrations/20260323000012_quiz_attempt_number_trigger.sql` | Attempt number trigger + UNIQUE |

## Known Issues & Tech Debt

1. **`quiz_passed` never written to DB** (#1): `supabase_book_repository.dart` `updateReadingProgress` omits the field from the upsert map. `is_completed` IS written, masking the bug. The column is dead for queries/reporting. Fix: add `'quiz_passed': progress.quizPassed` to the data map.
2. **`get_best_book_quiz_result` missing auth** (#2): Any authenticated user can query any other user's best quiz score. Fix: add school-membership check matching `get_student_quiz_results` pattern, or add `WHERE user_id = auth.uid()` for student calls and a separate teacher-scoped variant.
3. **0-question quiz soft-lock** (#3): Published quiz with no questions prevents book completion. Fix: add `AND EXISTS (SELECT 1 FROM book_quiz_questions WHERE quiz_id = bq.id)` to `book_has_quiz` RPC, or guard in `isQuizReadyProvider`.
4. **Type parsing duplication** (#8): `BookQuizQuestionModel` has `_parseType`/`_typeToString` that duplicate `BookQuizQuestionType.fromDbValue()`/`.dbValue`. Should use the shared enum methods.
5. **Admin Turkish labels** (#11): All admin quiz editor UI is in Turkish. Needs English translation per architecture rule.
6. **`time_spent` always null** (#6): Quiz screen never measures elapsed time. Either implement timing or remove the column.
7. **`quiz.instructions` not shown** (#16): Field exists in DB and model but UI blocks for displaying it are commented out. Either remove or restore.
