# Book Quiz Audit Fixes Design

**Date:** 2026-03-27
**Source:** `docs/specs/04-book-quiz.md` audit findings
**Scope:** Fix all 12 actionable issues from the Book Quiz feature audit

---

## Context

The Book Quiz feature audit (`docs/specs/04-book-quiz.md`) identified 16 issues. 4 were already accepted/deferred. This design addresses the remaining 12 in a single pass.

## Changes

### Group 1 — Bug Fixes (High Severity)

#### #1 — `quiz_passed` never written to DB

**File:** `lib/data/repositories/supabase/supabase_book_repository.dart`

`updateReadingProgress` builds a `data` map for upsert but omits `quiz_passed`. The column stays `false` in DB forever despite `HandleBookCompletionUseCase` setting it to `true` via `copyWith`.

**Fix:** Add `'quiz_passed': progress.quizPassed` to the `data` map at line ~249.

#### #2 — `get_best_book_quiz_result` missing auth check

**File:** New migration

The RPC is `SECURITY DEFINER` with no authorization. Any authenticated user can query any other user's best quiz score by passing their `user_id`.

**Fix:** Replace the function with an authorized version. Add a check: caller must be `auth.uid() == p_user_id` (own results) OR teacher/admin/head in the same school. Return empty if unauthorized. Matches the pattern already used in `get_student_quiz_results`.

```sql
-- Pseudocode for the auth check
SELECT school_id INTO v_caller_school FROM profiles WHERE id = auth.uid();
SELECT school_id INTO v_student_school FROM profiles WHERE id = p_user_id;

IF auth.uid() != p_user_id THEN
  -- Must be teacher/admin/head in same school
  IF v_caller_role NOT IN ('teacher', 'head', 'admin')
     OR v_caller_school != v_student_school THEN
    RETURN;
  END IF;
END IF;
```

#### #3 — Published quiz with 0 questions soft-locks student

**Files:** New migration + `owlio_admin/.../book_quiz_edit_screen.dart`

A published quiz with no questions makes `bookHasQuizProvider` return `true` but the quiz screen shows "No quiz available." Student cannot complete the book.

**Fix (server):** Update `book_has_quiz` RPC to require at least one question:
```sql
WHERE book_id = p_book_id
AND is_published = true
AND EXISTS (SELECT 1 FROM book_quiz_questions WHERE quiz_id = bq.id)
```

**Fix (admin):** Add validation on quiz save — if question count is 0, show error SnackBar and prevent publish. English message: "Cannot publish a quiz with no questions."

### Group 2 — Code Quality (Medium Severity)

#### #8 — Type parsing duplication

**File:** `lib/data/models/book_quiz/book_quiz_model.dart`

`_parseType` and `_typeToString` duplicate `BookQuizQuestionType.fromDbValue()` / `.dbValue` from owlio_shared.

**Fix:** Replace both private methods with the shared enum methods. Remove the two switch statements.

#### #11 — Admin Turkish labels to English

**Files:** `owlio_admin/.../book_quiz_edit_screen.dart`, `owlio_admin/.../quiz_question_edit_screen.dart`

All user-facing strings are in Turkish. Violates CLAUDE.md "UI in English" rule.

**Fix:** Translate all Turkish strings to English. Key translations:
- "Kitap Quizini Duzenle" → "Edit Book Quiz"
- "Gecme Puani (%)" → "Passing Score (%)"
- "Coktan Secmeli" → "Multiple Choice"
- "Bosluk Doldurma" → "Fill in the Blank"
- "Olay Siralama" → "Event Sequencing"
- "Eslestirme" → "Matching"
- "Kim Ne Dedi" → "Who Says What"
- "Iptal" → "Cancel"
- "Kaydet" → "Save"
- Error/success SnackBar messages

### Group 3 — Dead Code & Cleanup (Low Severity)

#### #4 — Dead `answeredIndices` param

**Files:** `lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart`, `lib/presentation/screens/quiz/book_quiz_screen.dart`

`BookQuizProgressBar.answeredIndices` is accepted but never used. Progress is computed from `currentIndex`.

**Fix:** Remove `answeredIndices` from the constructor and all call sites.

#### #5 — Dead `_goToNextPage` condition

**File:** `lib/presentation/screens/quiz/book_quiz_screen.dart`

`_currentPage < 999` always evaluates to `true`, making the entire condition dead.

**Fix:** Remove the condition. Call `_pageController.nextPage(...)` directly. `nextPage` beyond the last page is a Flutter no-op.

#### #6 — Implement `timeSpent` measurement

**File:** `lib/presentation/screens/quiz/book_quiz_screen.dart`

The `time_spent` column and model field exist but are never populated.

**Fix:** Add `final _stopwatch = Stopwatch()..start()` in `initState`. Pass `_stopwatch.elapsed.inSeconds` to `submitQuiz` call. Wire through to `BookQuizResult` construction.

#### #7 — Unused `fromEntity` constructors

**File:** `lib/data/models/book_quiz/book_quiz_model.dart`

`BookQuizModel.fromEntity` and `BookQuizQuestionModel.fromEntity` are never called. Only `BookQuizResultModel.fromEntity` is used.

**Fix:** Remove `BookQuizModel.fromEntity` and `BookQuizQuestionModel.fromEntity`.

#### #9 — Raw string switches in admin

**File:** `owlio_admin/.../quiz_question_edit_screen.dart`

Switch cases use `'multiple_choice'` etc. instead of `BookQuizQuestionType.x.dbValue`.

**Fix:** Replace all raw string literals with enum `.dbValue` references.

#### #10 — Hard-coded colors

**File:** `lib/presentation/widgets/book_quiz/book_quiz_result_card.dart`

`Color(0xFF58CC02)` and `Color(0xFFFF4B4B)` are hard-coded.

**Fix:** Replace with `AppColors.primary` and the appropriate error/red color from the theme.

### Group 4 — DB Optimization (Low Severity)

#### #13 — Missing composite index

**File:** New migration

`getUserQuizResults` and `get_best_book_quiz_result` filter by `(user_id, book_id)` but no composite index exists.

**Fix:** New migration:
```sql
CREATE INDEX idx_book_quiz_results_user_book ON book_quiz_results(user_id, book_id);
```

## Migration Plan

All DB changes combined into a single migration file: `supabase/migrations/2026032XXXXXXX_book_quiz_audit_fixes.sql`

Contents:
1. `CREATE OR REPLACE FUNCTION book_has_quiz(...)` — add question existence check
2. `CREATE OR REPLACE FUNCTION get_best_book_quiz_result(...)` — add auth check
3. `CREATE INDEX idx_book_quiz_results_user_book ...` — composite index

## Files Modified (Summary)

| File | Changes |
|------|---------|
| `supabase/migrations/new_migration.sql` | 3 DB fixes (#2, #3 server, #13) |
| `lib/data/repositories/supabase/supabase_book_repository.dart` | Add `quiz_passed` to upsert (#1) |
| `lib/data/models/book_quiz/book_quiz_model.dart` | Use shared enum (#8), remove unused fromEntity (#7) |
| `lib/presentation/screens/quiz/book_quiz_screen.dart` | Stopwatch (#6), remove dead condition (#5), remove answeredIndices passing (#4) |
| `lib/presentation/widgets/book_quiz/book_quiz_progress_bar.dart` | Remove answeredIndices param (#4) |
| `lib/presentation/widgets/book_quiz/book_quiz_result_card.dart` | Use AppColors (#10) |
| `owlio_admin/.../book_quiz_edit_screen.dart` | English labels (#11), 0-question validation (#3 admin) |
| `owlio_admin/.../quiz_question_edit_screen.dart` | English labels (#11), enum dbValue switches (#9) |

## Out of Scope

- #12 (sequential async in HandleBookCompletionUseCase) — deferred, acceptable latency
- #14 (event sequencing auto-answer) — accepted design choice
- #15 (empty fill_blank submittable) — accepted UX
- #16 (commented-out instructions) — accepted, instructions feature may return
