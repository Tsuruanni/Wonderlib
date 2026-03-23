# Book Quiz Admin Integration — Design Spec

**Date:** 2026-03-23
**Scope:** Navigation fix + hardcoded XP fix + attempt_number race condition fix

---

## Problem Statement

The book quiz system is fully implemented in the main app and the admin panel has quiz editing screens, but three issues prevent proper integration:

1. **No navigation** from the book editor to the quiz editor in admin panel
2. **Hardcoded XP** (`'p_amount': 20`) in `supabase_book_quiz_repository.dart:145` instead of using `AppConfig.xpRewards`
3. **Race condition** on `attempt_number` — computed client-side via COUNT before INSERT, not atomic

---

## Out of Scope

- **Server-side grading** — client-side grading stays as-is (backlog item)
- **Quiz editor UX improvements** — existing editor screens are functional
- **Main app quiz screen/widgets** — no changes

---

## A. Admin Navigation: Book Editor → Quiz Editor

### Current State
- `book_edit_screen.dart` has a two-column layout: form (left, flex:2) + `_ChaptersList` (right, flex:1)
- Quiz routes exist in `router.dart`: `/books/:bookId/quiz`, `/books/:bookId/quiz/questions/new`, etc.
- No UI element links to these routes

### Design
Add a **Quiz section** above the chapters list inside the right panel's `_ChaptersList` widget. This keeps it in the same panel and doesn't require restructuring the layout.

**Quiz section behavior:**
- Fetches quiz existence via `supabase.from(DbTables.bookQuizzes).select('id, passing_score, total_points, is_published, book_quiz_questions(id)').eq('book_id', bookId).maybeSingle()`
- **Quiz exists:** Shows a summary card with question count, passing score, published status, and "Quiz Düzenle" (`FilledButton`) navigating to `/books/$bookId/quiz`
- **No quiz:** Shows "Quiz Oluştur" (`OutlinedButton.icon` with `Icons.quiz`) navigating to `/books/$bookId/quiz` (the quiz edit screen already handles creation)

**Visual placement:** Above the "Bölümler" header, separated by a divider. Uses the same indigo accent (`Color(0xFF4F46E5)`) and card styling as the rest of the admin panel.

### Files Changed
- `owlio_admin/lib/features/books/screens/book_edit_screen.dart` — add quiz section to `_ChaptersList`

---

## B. Hardcoded XP → AppConfig

### Current State
`supabase_book_quiz_repository.dart:145`:
```dart
'p_amount': 20, // Book completion XP
```

`AppConfig.xpRewards` already has a `'book_complete': 200` entry but no `'quiz_pass'` entry. The 20 XP is for quiz passing (not full book completion), so it needs its own key.

### Design
1. Add `'quiz_pass': 20` to `AppConfig.xpRewards` map
2. Replace the hardcoded `20` with `AppConfig.xpRewards['quiz_pass']!`

### Files Changed
- `lib/core/config/app_config.dart` — add `'quiz_pass': 20` entry
- `lib/data/repositories/supabase/supabase_book_quiz_repository.dart` — use `AppConfig.xpRewards['quiz_pass']!`

---

## C. Attempt Number: DB Trigger

### Current State
`supabase_book_quiz_repository.dart:60-64`:
```dart
final countResponse = await _supabase
    .from(DbTables.bookQuizResults)
    .select('id')
    .eq('user_id', result.userId)
    .eq('quiz_id', result.quizId);
final attemptNumber = (countResponse as List).length + 1;
```
This is not atomic — concurrent requests can produce duplicate attempt numbers.

### Design
1. **New migration** with a `BEFORE INSERT` trigger on `book_quiz_results`:
   ```sql
   CREATE OR REPLACE FUNCTION set_quiz_attempt_number()
   RETURNS TRIGGER AS $$
   BEGIN
     NEW.attempt_number := COALESCE(
       (SELECT MAX(attempt_number) FROM book_quiz_results
        WHERE user_id = NEW.user_id AND quiz_id = NEW.quiz_id),
       0
     ) + 1;
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql;

   CREATE TRIGGER trg_set_quiz_attempt_number
     BEFORE INSERT ON book_quiz_results
     FOR EACH ROW
     EXECUTE FUNCTION set_quiz_attempt_number();
   ```
2. **Remove client-side COUNT** from `submitQuizResult` in `supabase_book_quiz_repository.dart`
3. **Remove `attempt_number` from `toInsertJson()`** in `BookQuizResultModel` (trigger handles it)
4. The INSERT...RETURNING will include the trigger-set `attempt_number`, so the parsed response still has the correct value

### Files Changed
- `supabase/migrations/20260323000001_quiz_attempt_number_trigger.sql` — new migration
- `lib/data/repositories/supabase/supabase_book_quiz_repository.dart` — remove COUNT logic
- `lib/data/models/book_quiz/book_quiz_result_model.dart` — remove `attempt_number` from `toInsertJson()`

---

## Summary of All Files Changed

| File | Change |
|------|--------|
| `owlio_admin/lib/features/books/screens/book_edit_screen.dart` | Quiz section in right panel |
| `lib/core/config/app_config.dart` | Add `quiz_pass` XP key |
| `lib/data/repositories/supabase/supabase_book_quiz_repository.dart` | Use AppConfig XP + remove COUNT |
| `lib/data/models/book_quiz/book_quiz_result_model.dart` | Remove attempt_number from insert |
| `supabase/migrations/20260323000001_quiz_attempt_number_trigger.sql` | BEFORE INSERT trigger |

---

## Verification

```bash
# Flutter analyze (both projects)
dart analyze lib/
cd owlio_admin && dart analyze lib/

# Migration dry-run
supabase db push --dry-run

# Manual test: open book editor → see quiz section → navigate to quiz editor
# Manual test: submit quiz → verify attempt_number is correct in DB
```
