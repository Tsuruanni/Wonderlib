# Vocabulary Assignment Completion

## Problem

When a teacher creates a vocabulary assignment (assigns a word list to a class), students can never complete it. The student detail screen navigates to the general vocabulary hub instead of the assigned word list, and session completion has no hook to update assignment progress. The assignment stays `pending`/`in_progress` forever.

Book assignments work correctly — chapter completion triggers `_updateAssignmentProgress` in `book_provider.dart`. Vocabulary assignments need an equivalent mechanism.

## Decision

- **Completion criteria:** One completed session on the assigned word list marks the assignment as complete.
- **Navigation:** Tapping the vocabulary assignment card navigates directly to the word list session (not the vocabulary hub).
- **Score:** The session's accuracy percentage is stored as the assignment score.

## Design

### 1. Add `wordListId` getter to `StudentAssignment` entity

**File:** `lib/domain/entities/student_assignment.dart`

Add a computed getter (mirrors existing `bookId` getter):

```dart
String? get wordListId {
  if (type == StudentAssignmentType.vocabulary || type == StudentAssignmentType.mixed) {
    return contentConfig['wordListId'] as String?;
  }
  return null;
}
```

### 2. Update student assignment detail screen navigation

**File:** `lib/presentation/screens/student/student_assignment_detail_screen.dart`

Replace the vocabulary `_ContentCard.onTap` handler. Instead of `context.go(AppRoutes.vocabulary)`:

1. Read `wordListId` from `assignment.wordListId`
2. If status is `pending`, call `StartAssignmentUseCase` (same pattern as `_startReading`)
3. Navigate to word list session: `context.go(AppRoutes.wordListSessionPath(assignment.wordListId!))`
4. Invalidate assignment providers

This requires verifying that a route exists for starting a word list session directly. If not, use the existing word list detail route that has a "Start Practice" button.

### 3. Add assignment completion hook to session summary

**File:** `lib/presentation/screens/vocabulary/session_summary_screen.dart`

After `_saveSession` succeeds (inside the `result.fold` success branch):

1. Call `GetActiveAssignmentsUseCase` to fetch active assignments for the current user
2. Find any assignment where `assignment.wordListId == widget.listId` and `assignment.status != completed`
3. If found, call `CompleteAssignmentUseCase` with `score = accuracy`
4. Invalidate `studentAssignmentsProvider`, `activeAssignmentsProvider`, and `studentAssignmentDetailProvider(assignmentId)`

This mirrors the pattern in `book_provider.dart:_updateAssignmentProgress` but simplified: no progress percentage calculation needed (it's either 0% or 100%).

### 4. Route verification

Check that a direct route to start a vocabulary session for a specific word list exists. Candidates:
- `AppRoutes.wordListSession` or similar
- `AppRoutes.wordListDetailPath(id)` → detail screen with "Start" button

If no direct session route exists, navigate to the word list detail screen instead. The key requirement is that the student lands on a screen where they can start practicing the assigned word list without manual searching.

## Files Changed

| File | Change |
|------|--------|
| `lib/domain/entities/student_assignment.dart` | Add `wordListId` getter |
| `lib/presentation/screens/student/student_assignment_detail_screen.dart` | Update vocabulary card navigation + start assignment logic |
| `lib/presentation/screens/vocabulary/session_summary_screen.dart` | Add assignment completion hook after session save |

## No New Files

All changes are modifications to existing files. No new UseCases, repositories, or models needed — the existing `GetActiveAssignmentsUseCase`, `StartAssignmentUseCase`, and `CompleteAssignmentUseCase` cover all operations.

## Edge Cases

| Case | Behavior |
|------|----------|
| Word list deleted after assignment created | `wordListId` getter returns the UUID but navigation will fail. Out of scope — same issue exists for book assignments. |
| Student completes session without going through assignment | Assignment still gets completed — the hook checks all active assignments regardless of entry point. |
| Multiple assignments with same word list | First matching non-completed assignment gets completed. Subsequent sessions complete the next one. |
| Mixed assignment type | `wordListId` getter handles mixed type. Book and vocabulary completion are independent hooks — each completes when its respective content is done. |
| Assignment already completed | Guard `status != completed` prevents double-completion. |
