# Vocabulary Assignment Completion

## Problem

When a teacher creates a vocabulary assignment (assigns a word list to a class), students can never complete it. The student detail screen navigates to the general vocabulary hub instead of the assigned word list, and session completion has no hook to update assignment progress. The assignment stays `pending`/`in_progress` forever.

Book assignments work correctly — chapter completion triggers `_updateAssignmentProgress` in `book_provider.dart`. Vocabulary assignments need an equivalent mechanism.

## Decision

- **Completion criteria:** One completed session on the assigned word list marks the assignment as complete.
- **Navigation:** Tapping the vocabulary assignment card navigates to the assigned word list's detail screen (`vocabularyListPath`).
- **Score:** The session's accuracy percentage is stored as the assignment score.

## Design

### 1. Add `wordListId` getter to `StudentAssignment` entity

**File:** `lib/domain/entities/student_assignment.dart`

Add a computed getter (mirrors existing `bookId` getter):

```dart
String? get wordListId {
  if (type == StudentAssignmentType.vocabulary) {
    return contentConfig['wordListId'] as String?;
  }
  return null;
}
```

Note: `mixed` type is excluded because `CreateAssignmentUseCase` does not populate `wordListId` in `contentConfig` for mixed assignments. Adding `mixed` support here would be dead code.

### 2. Update student assignment detail screen navigation

**File:** `lib/presentation/screens/student/student_assignment_detail_screen.dart`

Extract vocabulary navigation into a `_startVocabulary` method (mirrors `_startReading`):

1. Read `wordListId` from `assignment.wordListId` — return early if null
2. If status is `pending`, call `StartAssignmentUseCase` (same pattern as `_startReading`)
3. Navigate to word list detail: `context.go(AppRoutes.vocabularyListPath(assignment.wordListId!))`
4. Invalidate assignment providers

The detail screen shows the word list contents and has a "Start Session" button — the student sees what they'll practice before starting.

### 3. Add assignment completion hook to session summary

**File:** `lib/presentation/screens/vocabulary/session_summary_screen.dart`

After `_saveSession` succeeds (inside the `result.fold` success branch):

1. Call `GetActiveAssignmentsUseCase` to fetch active assignments for the current user
2. Find **all** assignments where `assignment.wordListId == widget.listId` and `assignment.status != completed`
3. For each match, call `CompleteAssignmentUseCase` with `score = accuracy`, using `assignment.assignmentId` (not `assignment.id`)
4. Invalidate `studentAssignmentsProvider`, `activeAssignmentsProvider`, and `studentAssignmentDetailProvider(assignment.assignmentId)` for each completed assignment

**Error handling:** Wrap the entire hook in try-catch. Assignment completion failure must not affect the session save success flow — log the error with `debugPrint`, do not show it to the user. This matches the book pattern in `book_provider.dart` lines 295-298.

This mirrors `book_provider.dart:_updateAssignmentProgress` but simplified: no progress percentage calculation needed (it's either 0% or 100%).

## Files Changed

| File | Change |
|------|--------|
| `lib/domain/entities/student_assignment.dart` | Add `wordListId` getter |
| `lib/presentation/screens/student/student_assignment_detail_screen.dart` | Add `_startVocabulary` method, update vocabulary card `onTap` |
| `lib/presentation/screens/vocabulary/session_summary_screen.dart` | Add assignment completion hook after session save |

## No New Files

All changes are modifications to existing files. No new UseCases, repositories, or models needed — the existing `GetActiveAssignmentsUseCase`, `StartAssignmentUseCase`, and `CompleteAssignmentUseCase` cover all operations.

## Edge Cases

| Case | Behavior |
|------|----------|
| Word list deleted after assignment created | `wordListId` getter returns the UUID but navigation will fail. Out of scope — same issue exists for book assignments. |
| Student completes session without going through assignment | Assignment still gets completed — the hook checks all active assignments regardless of entry point. |
| Multiple assignments with same word list | All matching non-completed assignments get completed in one pass (matches book pattern behavior). |
| Mixed assignment type | Not supported — `CreateAssignmentUseCase` doesn't populate `wordListId` for mixed. `wordListId` getter returns null. |
| Assignment already completed | Guard `status != completed` prevents double-completion. |
| Hook failure | Silently logged, does not affect session save success. |
