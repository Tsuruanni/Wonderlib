# Teacher Library — Design Spec

**Date:** 2026-04-17
**Status:** Draft (awaiting user review)
**Target:** Owlio Mobile (Flutter) — teacher role

---

## 1. Summary

Add a **Library** section to the teacher panel that mirrors the student library, so teachers can browse books, experience the full reading flow (audio, karaoke, inline activities, book quiz), and assign books to their classes from any book detail screen. In this preview experience all inline-activity answers and all book-quiz answers are pre-filled so the teacher sees what students see with correct answers already revealed. No reading progress, XP, or completion state is persisted for the teacher.

---

## 2. Goals

- Give teachers a discoverable entry point to the full book catalog from their panel.
- Let teachers evaluate book content (activities and quiz) with answers visible, without leaving the student-facing reader UI.
- Let teachers create an assignment for any book directly from that book's detail screen.
- Reuse existing student library, book detail, reader, and book-quiz code — no parallel teacher-only copies.
- No database changes, no new RPCs, no new backend tables.

## 3. Non-goals

- Teacher-visible student answer reports in the reader (out of scope; lives in reports feature).
- "Copy quiz from preview into assignment" shortcut.
- Filtering Teacher Library by "only books I've assigned."
- Any new interactivity for teachers inside activities/quiz (they are display-only in preview).

---

## 4. User Stories

- As a teacher, I open the Library tab, browse all books, tap one, read it chapter by chapter, and see every activity and quiz question with the correct answer highlighted.
- As a teacher, on any book's detail screen I tap **Assign this Book** and am taken to the existing assignment-creation screen with the book pre-selected.
- As a teacher, I can freely jump between chapters and open the book quiz at any time without having to "complete" anything first.
- As a teacher, my navigation through the book does not create any reading progress, chapter completion, XP, or quiz attempt for my account.

---

## 5. Architecture Overview

**Approach:** Reuse existing screens and widgets; gate behavior on a single role-derived provider.

A new provider `isTeacherPreviewModeProvider` returns `true` when the current user has role `teacher`. Every place that needs to behave differently for a teacher reading the book (progress saves, access gates, activity state initialization, quiz state initialization, banner visibility) watches this provider.

Rationale:
- Teachers never go through the student reading flow as students. Role equality is a sufficient and accurate signal.
- A single provider means one place to change the policy later (e.g. if an explicit "preview mode toggle" is ever needed).
- Avoids threading a boolean through every widget constructor.

No new domain entities or use cases are introduced. All gates and bypasses happen at the provider or use-case-caller layer in the presentation tier.

---

## 6. Navigation

### 6.1 Teacher shell

File: `lib/presentation/screens/teacher/teacher_shell_scaffold.dart`

Add a 5th destination **after** Reports:

| # | Destination | Route |
|---|---|---|
| 1 | Dashboard | `/teacher/dashboard` |
| 2 | Classes | `/teacher/classes` |
| 3 | Assignments | `/teacher/assignments` |
| 4 | Reports | `/teacher/reports` |
| 5 | **Library** (new) | `/teacher/library` |

Icon: `Icons.menu_book_outlined` (selected state: `Icons.menu_book`).
Label: `"Library"`.

### 6.2 Route

In the teacher router config (`lib/core/routes/app_routes.dart` + associated router file), add a new `StatefulShellBranch` whose root route is `/teacher/library`. The branch's screen body is the existing `LibraryScreen` widget.

`LibraryScreen` already uses `booksProvider(null)` which returns all books the current user can access, and `bookLockProvider` already returns empty for `UserRole.teacher` — so no scoping changes are needed.

### 6.3 Deep-link entry from assign flow

Not changed. Existing route `/teacher/create-assignment` (with book context extras) continues to serve the assign flow.

---

## 7. Teacher Preview Mode Provider

**New file:** `lib/presentation/providers/teacher_preview_provider.dart`

```dart
final isTeacherPreviewModeProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role == UserRole.teacher;
});
```

Keep it deliberately tiny. No parameters. No overrides. Read from anywhere in the presentation layer.

---

## 8. Access Gate Bypasses

All of the following must return "allowed" / no-op when `isTeacherPreviewModeProvider` is `true`.

### 8.1 Already bypassed ✅
- `bookLockProvider` — returns empty for teachers (see `lib/presentation/providers/book_access_provider.dart`).

### 8.2 To patch

These providers / use cases need a `isTeacherPreviewModeProvider`-based bypass added. Exact names to be confirmed in the implementation plan after tracing the student-side code:

- **Chapter sequential-unlock gate** — teacher must be able to tap any chapter without having completed the previous one. If chapter access is determined by a provider like `canAccessChapterProvider` or inline logic in the reader, add a teacher-preview short-circuit.
- **Book quiz unlock gate** — student rules require all chapters completed before quiz opens. For teachers the quiz entry in the chapter list / reader sidebar is always tappable.
- **Reading progress save** — wherever `UpdateCurrentChapterUseCase` and `SaveReadingProgressUseCase` are invoked from the reader, the call is skipped when in teacher preview mode.

The gate surface for teachers is: library (unlocked), chapters (unlocked), quiz (unlocked), progress writes (suppressed).

---

## 9. Book Detail Screen (teacher FAB)

**File:** `lib/presentation/screens/library/book_detail_screen.dart`

Current state: For teachers, the FAB shows only **Assign Book** (lines ~365-393). For students, it shows **Start Reading**.

New state for teachers: **two buttons side by side** (or stacked, whichever matches the app's existing two-action pattern):

1. **Start Reading** — same destination as the student flow (`AppRoutes.readerPath(bookId, chapterId)`). Teacher preview mode is derived from the user role, so the reader automatically enters preview mode.
2. **Assign this Book** — existing behavior, routes to `/teacher/create-assignment` with book extras.

No new route, no new screen.

---

## 10. Assign Flow (unchanged backend)

This flow already exists end-to-end. Documented here only to make the contract explicit.

### 10.1 UI flow

1. Teacher taps **Assign this Book** on `BookDetailScreen`.
2. Navigation to `/teacher/create-assignment` with extras:
   - `preSelectedBookId: book.id`
   - `preSelectedBookTitle: book.title`
   - `preSelectedBookChapterCount: book.chapters.length`
3. `CreateAssignmentScreen` opens with:
   - Assignment type locked to **Book**.
   - Book field pre-filled with the book's title (no re-selection needed).
   - Teacher fills: title, description (optional), class (dropdown), start date, due date, `Lock library to this book` toggle.
4. On submit → `CreateAssignmentUseCase(CreateAssignmentParams(...))` → returns `Either<Failure, Assignment>`.

### 10.2 Backend (already built)

- INSERT into `DbTables.assignments` with columns: `teacher_id`, `class_id`, `type='book'`, `book_id`, `title`, `description`, `start_date`, `due_date`, `lock_library`, `created_at` (TIMESTAMPTZ, UTC).
- Existing triggers/flows that fan out `assignment_progress` per student in the class, notify students, and honor class-change sync are not modified.

### 10.3 Required changes for this feature

**None.** The assign flow is a reused dependency, not a new build.

---

## 11. Reader — Teacher Preview UX

**File:** `lib/presentation/screens/reader/reader_screen.dart`

### 11.1 Preview banner

New widget: `lib/presentation/widgets/teacher_preview_banner.dart`

- Thin horizontal strip, ~36 px tall, rendered immediately below the reader AppBar.
- Background: theme warning / info tint (muted, non-alarming).
- Text: `"Teacher Preview — Showing correct answers · No progress saved"`.
- Visibility: gated on `isTeacherPreviewModeProvider`.

### 11.2 Progress write suppression

At every call site in `reader_screen.dart` (and any child providers) that calls `UpdateCurrentChapterUseCase` or `SaveReadingProgressUseCase`, wrap with `if (!ref.read(isTeacherPreviewModeProvider)) { ... }`. Prefer guarding **inside the provider/notifier** that owns the call so the caller widget stays simple.

### 11.3 Chapter free-navigation

Whatever provider / logic currently computes "can the student open chapter N" returns `true` unconditionally when `isTeacherPreviewModeProvider` is true. Chapter list item `onTap` handlers are otherwise unchanged.

### 11.4 Quiz entry point from reader

No new button. The existing quiz entry that appears after the last chapter (or in the reader sidebar / chapter list) becomes tappable immediately for teachers because the access gate is bypassed. When tapped, `BookQuizScreen` opens in preview mode (section 13).

---

## 12. Inline Activities — Pre-filled Answers

Inline activities render inside content blocks in the reader. There are 4 types (from `docs/specs/03-inline-activities.md`):

| Activity type | Preview behavior |
|---|---|
| `true_false` | `selectedAnswer` initialized to `correctAnswer`; the chosen option rendered with the standard "correct" style (e.g. green border + check). |
| `word_translation` | The correct option chip is initialized as selected and styled "correct". |
| `find_words` | Each word in `correctAnswers` is initialized as selected / highlighted. |
| `matching` | All correct pairs are initialized as connected; lines drawn as if matched correctly. |

### 12.1 Implementation approach

Inline activity state is managed by notifier(s) in `lib/presentation/providers/reader_provider.dart` (exact notifier boundaries TBC in implementation). For each activity type's state notifier:

- If `ref.read(isTeacherPreviewModeProvider)` is true at construction / first-read time, initialize state with the content block's `correctAnswer(s)` pre-selected.
- Any `submit` / `markCompleted` / `awardXp` path in these notifiers becomes a no-op in teacher preview mode.

The activity widgets themselves do not change their visual style — they just receive a pre-populated state and render it.

### 12.2 Tap handling in preview

In teacher preview mode all activity-interaction tap handlers (option taps, word selections, pair connections, drag targets) are **no-ops**: they neither mutate state nor fire completion. The widgets display the pre-filled correct answer and remain visually static. This keeps the "no progress saved" promise unambiguous and removes any risk of state leaking through widget-level gestures.

---

## 13. Book Quiz — Pre-filled Answers

**File:** `lib/presentation/screens/quiz/book_quiz_screen.dart`

Current behavior: quiz shows one question per page via `PageView`; user answers collected into `Map<String, dynamic> _answers`; submit calls `GradeBookQuizUseCase`.

### 13.1 Preview behavior

In `initState`, if `ref.read(isTeacherPreviewModeProvider)` is `true`, pre-populate `_answers` from each question's correct-answer field on the quiz model:

| Question type | Pre-filled value |
|---|---|
| `multiple_choice` | `correctAnswer` |
| `fill_blank` | `correctAnswer` written into the text field controller |
| `event_sequencing` | Items ordered per `correctOrder` |
| `matching` | Pairs connected per `correctPairs` |
| `who_says_what` | Pairs assigned per `correctPairs` |

### 13.2 Submit button replaced

In teacher preview mode the Submit button is replaced by **"Exit Preview"** which simply pops the quiz screen. `GradeBookQuizUseCase` is **not** called, no attempt row is written, no XP is awarded.

### 13.3 Answer visibility styling

Answer pre-fills reuse the existing "selected" / "entered" styles — same visual affordance the student sees while taking the quiz. No separate "this is the correct answer" marker is needed because the pre-filled state IS the answer.

---

## 14. File Manifest

### 14.1 New files (2)

- `lib/presentation/providers/teacher_preview_provider.dart` — the `isTeacherPreviewModeProvider`.
- `lib/presentation/widgets/teacher_preview_banner.dart` — the reader banner widget.

### 14.2 Modified files

- `lib/presentation/screens/teacher/teacher_shell_scaffold.dart` — add 5th Library destination.
- `lib/core/routes/app_routes.dart` (+ the router file that declares teacher branches) — add `/teacher/library` branch using existing `LibraryScreen`.
- `lib/presentation/screens/library/book_detail_screen.dart` — teacher FAB now shows both Start Reading and Assign this Book.
- `lib/presentation/screens/reader/reader_screen.dart` — render preview banner when in teacher preview mode; ensure progress-write call sites are suppressed.
- `lib/presentation/providers/reader_provider.dart` — teacher-preview initial state for inline-activity notifier(s); no-op completion paths.
- `lib/presentation/screens/quiz/book_quiz_screen.dart` — teacher-preview `initState` pre-fill; replace Submit with Exit Preview.
- Chapter-access gate provider(s) — name to be located in implementation; add teacher-preview bypass.
- Quiz-access gate provider(s) — name to be located in implementation; add teacher-preview bypass.

### 14.3 Unchanged (explicitly called out)

- Assign flow screens and use cases.
- Assignment repository and Supabase schema.
- Audio / karaoke code paths.
- Student-facing library, reader, and quiz behavior (regression risk mitigated by routing all teacher-specific logic through `isTeacherPreviewModeProvider`).

### 14.4 Database / backend

**No migrations. No new RPCs. No edge-function changes.**

---

## 15. Testing / Verification Plan

### 15.1 Manual smoke (teacher)

- Log in as a teacher. Verify the 5th **Library** tab is present and reachable.
- Open Library → grid of all books visible, no lock overlays.
- Tap a book → Book Detail shows **Start Reading** and **Assign this Book** buttons.
- Tap **Start Reading** → Reader opens with the Teacher Preview banner visible.
- Tap any chapter out of order (e.g. chapter 3 before chapter 1) → it opens.
- Inside a chapter, every inline activity renders with the correct answer(s) pre-selected/highlighted.
- From the reader's chapter/quiz list, open the book quiz without completing any chapter → quiz opens; every question shows the correct answer pre-filled; submit button is labeled **Exit Preview**; tapping it returns to the reader without calling grading.
- Exit the book entirely. In Supabase, confirm no new rows in reading progress, chapter progress, quiz attempts, or XP logs for this teacher.
- From Book Detail, tap **Assign this Book** → CreateAssignment screen opens with book pre-filled; complete the form; verify the assignment row is written and students in the selected class receive it (existing behavior).

### 15.2 Regression (student)

- Log in as each test student (fresh / active / advanced).
- Library, book detail, reader, inline activities, book quiz all behave exactly as before.
- Reading progress, chapter completion, XP awards, quiz grading unaffected.
- Book locks still apply when `lock_library` assignments are active.

### 15.3 Static checks

- `dart analyze lib/` must pass with zero new warnings.
- No screen imports a repository directly (CLAUDE.md architectural rule).

---

## 16. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Missing a progress-write call site → teacher accidentally writes progress. | During implementation, grep every invocation of `UpdateCurrentChapterUseCase`, `SaveReadingProgressUseCase`, chapter-complete award paths, and gate each at the provider level, not widget level. Manual verification via Supabase row count after a teacher session. |
| Inline-activity state notifiers turn out to be per-type with divergent APIs. | Handle each of the 4 types individually in the implementation plan. Keep a consistent pattern: "if preview mode, initialize with correct answer; no-op completion path." |
| Activity / quiz widgets assume fresh empty state and crash on pre-filled data. | Address in implementation — the pre-filled state is the same shape a completed student state would have, so this should be low risk, but unit-test each widget if needed. |
| Audio / karaoke tied to progress saves. | If audio completion triggers a progress-save path, gate that path with the preview provider too. Confirm during implementation tracing. |
| Teacher role accidentally enters this flow from an unexpected entry point and preview mode engages unintentionally. | Acceptable: the preview banner makes the mode explicit; no harm done because no writes happen. If ever a teacher needs a "student simulation" mode later, the provider can be extended to an enum. |

---

## 17. Open Questions

*(Filled in during review; none at the time of writing.)*

---

## 18. Out-of-Scope Follow-ups

- A "preview student's answers" mode where the teacher sees what a specific student answered.
- Teacher analytics on book difficulty derived from class quiz results.
- Filter chips on Teacher Library ("Assigned by me", "Assigned this week").
- Teacher-specific bookmarking or notes in the reader.
