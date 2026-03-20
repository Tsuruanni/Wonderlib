# Vocabulary Assignment Completion — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable vocabulary assignments to be completed when a student finishes one session on the assigned word list.

**Architecture:** Three surgical edits to existing files — add a getter, fix navigation, add a completion hook. No new files, models, or use cases. Mirrors the book assignment completion pattern already in `book_provider.dart`.

**Tech Stack:** Flutter, Riverpod, GoRouter, dartz (Either pattern)

**Spec:** `docs/superpowers/specs/2026-03-20-vocabulary-assignment-completion-design.md`

---

### Task 1: Add `wordListId` getter to `StudentAssignment` entity

**Files:**
- Modify: `lib/domain/entities/student_assignment.dart:116-132` (after `bookId` getter)

- [ ] **Step 1: Add the `wordListId` getter**

In `lib/domain/entities/student_assignment.dart`, add this getter after the `bookId` getter (after line 122, before the `chapterIds` getter):

```dart
  /// Get word list ID if this is a vocabulary assignment
  String? get wordListId {
    if (type == StudentAssignmentType.vocabulary) {
      return contentConfig['wordListId'] as String?;
    }
    return null;
  }
```

- [ ] **Step 2: Verify no analysis errors**

Run: `dart analyze lib/domain/entities/student_assignment.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/student_assignment.dart
git commit -m "feat: add wordListId getter to StudentAssignment entity"
```

---

### Task 2: Update vocabulary assignment navigation in student detail screen

**Files:**
- Modify: `lib/presentation/screens/student/student_assignment_detail_screen.dart:374-385` (vocabulary `_ContentCard`) and add `_startVocabulary` method

**Context:** The `_startReading` method (lines 400-425) is the pattern to follow. It checks if status is `pending`, calls `StartAssignmentUseCase`, then navigates. We create an identical `_startVocabulary` method.

- [ ] **Step 1: Add `_startVocabulary` method to `_AssignmentDetailContent`**

In `lib/presentation/screens/student/student_assignment_detail_screen.dart`, add this method after the `_startReading` method (after line 425, before the closing `}` of `_AssignmentDetailContent`):

```dart
  void _startVocabulary(BuildContext context, WidgetRef ref, StudentAssignment assignment) async {
    if (assignment.wordListId == null) return;

    // Start the assignment if not started
    if (assignment.status == StudentAssignmentStatus.pending) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final useCase = ref.read(startAssignmentUseCaseProvider);
        await useCase(StartAssignmentParams(
          studentId: userId,
          assignmentId: assignment.assignmentId,
        ));
        ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        ref.invalidate(studentAssignmentsProvider);
      }
    }

    if (context.mounted) {
      context.go(AppRoutes.vocabularyListPath(assignment.wordListId!));
    }
  }
```

- [ ] **Step 2: Update vocabulary `_ContentCard` `onTap` to call `_startVocabulary`**

In the same file, replace lines 374-386 (the vocabulary `_ContentCard` block):

Old:
```dart
                if (assignment.type == StudentAssignmentType.vocabulary ||
                    assignment.type == StudentAssignmentType.mixed) ...[
                  _ContentCard(
                    icon: Icons.abc,
                    title: 'Complete vocabulary practice',
                    subtitle: 'Learn and review words',
                    color: Colors.purple,
                    onTap: () {
                      // Navigate to vocabulary
                      context.go(AppRoutes.vocabulary);
                    },
                  ),
                ],
```

New:
```dart
                if (assignment.type == StudentAssignmentType.vocabulary ||
                    assignment.type == StudentAssignmentType.mixed) ...[
                  _ContentCard(
                    icon: Icons.abc,
                    title: 'Complete vocabulary practice',
                    subtitle: 'Learn and review words',
                    color: Colors.purple,
                    onTap: assignment.wordListId != null
                        ? () => _startVocabulary(context, ref, assignment)
                        : null,
                  ),
                ],
```

- [ ] **Step 3: Verify no analysis errors**

Run: `dart analyze lib/presentation/screens/student/student_assignment_detail_screen.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/student/student_assignment_detail_screen.dart
git commit -m "feat: navigate to assigned word list from vocabulary assignment"
```

---

### Task 3: Add assignment completion hook to session summary

**Files:**
- Modify: `lib/presentation/screens/vocabulary/session_summary_screen.dart:109-137` (the `result.fold` success branch)

**Context:** After `_saveSession` succeeds (line 123, `(savedResult) {` branch), we add assignment completion logic. Required imports and providers are already available in the file (`usecase_providers.dart` is imported, `currentUserIdProvider` is imported via `auth_provider.dart`). We need to add imports for assignment-related types.

- [ ] **Step 1: Add required imports**

In `lib/presentation/screens/vocabulary/session_summary_screen.dart`, add these imports after line 11 (after the `complete_session_usecase.dart` import):

```dart
import '../../../domain/entities/student_assignment.dart';
import '../../../domain/usecases/student_assignment/complete_assignment_usecase.dart';
import '../../../domain/usecases/student_assignment/get_active_assignments_usecase.dart';
import '../../providers/student_assignment_provider.dart';
```

- [ ] **Step 2: Add `_completeVocabularyAssignment` method**

Add this method to `_SessionSummaryScreenState` (after the `_saveSession` method, before `dispose`):

```dart
  Future<void> _completeVocabularyAssignment(double accuracy) async {
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final getActiveAssignmentsUseCase = ref.read(getActiveAssignmentsUseCaseProvider);
      final result = await getActiveAssignmentsUseCase(
        GetActiveAssignmentsParams(studentId: userId),
      );

      final assignments = result.fold(
        (failure) => <StudentAssignment>[],
        (assignments) => assignments,
      );

      for (final assignment in assignments) {
        if (assignment.wordListId == widget.listId &&
            assignment.status != StudentAssignmentStatus.completed) {
          final completeAssignmentUseCase = ref.read(completeAssignmentUseCaseProvider);
          await completeAssignmentUseCase(CompleteAssignmentParams(
            studentId: userId,
            assignmentId: assignment.assignmentId,
            score: accuracy,
          ));
          ref.invalidate(studentAssignmentsProvider);
          ref.invalidate(activeAssignmentsProvider);
          ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }
    } catch (e) {
      debugPrint('Assignment completion failed: $e');
    }
  }
```

- [ ] **Step 3: Call the hook from `_saveSession` success branch**

In `_saveSession`, inside the `(savedResult) {` success callback (after line 131, after `ref.read(userControllerProvider.notifier).refresh();`), add:

```dart
        // Complete any vocabulary assignments for this word list
        _completeVocabularyAssignment(accuracy);
```

Note: `accuracy` is already computed on line 85-89 and is in scope within `_saveSession`.

- [ ] **Step 4: Verify no analysis errors**

Run: `dart analyze lib/presentation/screens/vocabulary/session_summary_screen.dart`
Expected: No issues found

- [ ] **Step 5: Run full project analysis**

Run: `dart analyze lib/`
Expected: No errors (warnings are OK)

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/vocabulary/session_summary_screen.dart
git commit -m "feat: auto-complete vocabulary assignments on session finish"
```

---

### Task 4: Manual verification

- [ ] **Step 1: Verify with `dart analyze`**

Run: `dart analyze lib/`
Expected: No errors

- [ ] **Step 2: Check no architecture violations**

Run: `grep -r "ref\.\(read\|watch\).*RepositoryProvider" lib/presentation/screens/ | wc -l`
Expected: 0
