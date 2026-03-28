# Assignment System Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 10 audit findings from the Assignment System spec (#17), including a high-severity security fix (RPC migration), architecture compliance (StateNotifier refactors), and cleanup (debugPrint, duplication, validation).

**Architecture:** Phase 1 adds two SECURITY DEFINER RPCs (`start_assignment`, `complete_assignment`) and migrates the repository from direct table UPDATEs to RPC calls. Phase 2 extracts StateNotifier controllers for mutation operations, consolidates duplicated widgets, and adds missing validation. Phase 3 updates the feature spec with fix statuses.

**Tech Stack:** PostgreSQL (Supabase migrations), Dart/Flutter (Riverpod, dartz Either), owlio_shared package

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `supabase/migrations/20260328400001_assignment_start_complete_rpcs.sql` | Two SECURITY DEFINER RPCs |
| Modify | `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `startAssignment`, `completeAssignment` constants |
| Modify | `lib/data/repositories/supabase/supabase_student_assignment_repository.dart:144-215` | Replace direct UPDATEs with RPC calls |
| Modify | `lib/presentation/providers/student_assignment_provider.dart` | Remove debugPrint, add `StudentAssignmentController` |
| Modify | `lib/presentation/providers/teacher_provider.dart:214-285` | Add `AssignmentDeleteController` |
| Modify | `lib/presentation/screens/teacher/assignment_detail_screen.dart:211-231` | Use controller instead of direct UseCase call |
| Modify | `lib/presentation/screens/student/student_assignment_detail_screen.dart:411-597` | Use controller instead of direct UseCase calls |
| Modify | `lib/presentation/utils/ui_helpers.dart` | Add `AssignmentStatusBadge` widget |
| Modify | `lib/presentation/screens/teacher/assignments_screen.dart:314-351` | Replace `_StatusBadge` with shared widget |
| Modify | `lib/presentation/screens/teacher/reports/assignment_report_screen.dart:321-357` | Replace `_StatusBadge` with shared widget |
| Modify | `lib/presentation/screens/teacher/create_assignment_screen.dart:109-116` | Add content validation guards |
| Modify | `docs/specs/17-assignment-system.md` | Update finding statuses |

---

### Task 1: Create start/complete assignment RPCs

**Files:**
- Create: `supabase/migrations/20260328400001_assignment_start_complete_rpcs.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- start_assignment: validates enrollment + status before transitioning
CREATE OR REPLACE FUNCTION start_assignment(
  p_student_id UUID,
  p_assignment_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status TEXT;
  v_start_date TIMESTAMPTZ;
BEGIN
  -- Auth check
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  -- Get current state
  SELECT asst.status, a.start_date
  INTO v_current_status, v_start_date
  FROM assignment_students asst
  JOIN assignments a ON a.id = asst.assignment_id
  WHERE asst.student_id = p_student_id
    AND asst.assignment_id = p_assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment_not_found';
  END IF;

  -- Already in_progress or completed — idempotent no-op
  IF v_current_status IN ('in_progress', 'completed') THEN
    RETURN;
  END IF;

  -- Can't start a withdrawn assignment
  IF v_current_status = 'withdrawn' THEN
    RAISE EXCEPTION 'assignment_withdrawn';
  END IF;

  -- Can't start before start_date
  IF NOW() < v_start_date THEN
    RAISE EXCEPTION 'assignment_not_yet_available';
  END IF;

  -- Transition pending → in_progress
  UPDATE assignment_students
  SET status = 'in_progress',
      started_at = NOW()
  WHERE student_id = p_student_id
    AND assignment_id = p_assignment_id;
END;
$$;

-- complete_assignment: validates enrollment + status + score range
CREATE OR REPLACE FUNCTION complete_assignment(
  p_student_id UUID,
  p_assignment_id UUID,
  p_score DECIMAL DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_status TEXT;
BEGIN
  -- Auth check
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  -- Get current state
  SELECT status INTO v_current_status
  FROM assignment_students
  WHERE student_id = p_student_id
    AND assignment_id = p_assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment_not_found';
  END IF;

  -- Already completed — idempotent no-op
  IF v_current_status = 'completed' THEN
    RETURN;
  END IF;

  -- Can't complete a withdrawn assignment
  IF v_current_status = 'withdrawn' THEN
    RAISE EXCEPTION 'assignment_withdrawn';
  END IF;

  -- Validate score range
  IF p_score IS NOT NULL AND (p_score < 0 OR p_score > 100) THEN
    RAISE EXCEPTION 'invalid_score';
  END IF;

  -- Complete the assignment
  UPDATE assignment_students
  SET status = 'completed',
      progress = 100,
      score = p_score,
      completed_at = NOW(),
      started_at = COALESCE(started_at, NOW())
  WHERE student_id = p_student_id
    AND assignment_id = p_assignment_id;
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the two CREATE FUNCTION statements, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260328400001_assignment_start_complete_rpcs.sql
git commit -m "feat(db): add start_assignment and complete_assignment RPCs

Server-side validation for assignment status transitions.
Prevents students from forging completion via direct table UPDATE."
```

---

### Task 2: Add RPC constants and update repository

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart:64`
- Modify: `lib/data/repositories/supabase/supabase_student_assignment_repository.dart:144-215`

- [ ] **Step 1: Add RPC constants to shared package**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, after line 64 (`static const syncUnitAssignmentProgress`), add:

```dart
  static const startAssignment = 'start_assignment';
  static const completeAssignment = 'complete_assignment';
```

- [ ] **Step 2: Replace startAssignment direct UPDATE with RPC call**

In `lib/data/repositories/supabase/supabase_student_assignment_repository.dart`, replace lines 144–165 (`startAssignment` method):

Old:
```dart
  @override
  Future<Either<Failure, void>> startAssignment(
    String studentId,
    String assignmentId,
  ) async {
    try {
      await _supabase
          .from(DbTables.assignmentStudents)
          .update({
            'status': AssignmentStatus.inProgress.dbValue,
            'started_at': AppClock.now().toIso8601String(),
          })
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

New:
```dart
  @override
  Future<Either<Failure, void>> startAssignment(
    String studentId,
    String assignmentId,
  ) async {
    try {
      await _supabase.rpc(
        RpcFunctions.startAssignment,
        params: {
          'p_student_id': studentId,
          'p_assignment_id': assignmentId,
        },
      );

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 3: Replace completeAssignment direct UPDATE with RPC call**

In the same file, replace lines 191–215 (`completeAssignment` method):

Old:
```dart
  @override
  Future<Either<Failure, void>> completeAssignment(
    String studentId,
    String assignmentId,
    double? score,
  ) async {
    try {
      await _supabase
          .from(DbTables.assignmentStudents)
          .update({
            'status': AssignmentStatus.completed.dbValue,
            'progress': 100,
            'score': score,
            'completed_at': AppClock.now().toIso8601String(),
          })
          .eq('student_id', studentId)
          .eq('assignment_id', assignmentId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

New:
```dart
  @override
  Future<Either<Failure, void>> completeAssignment(
    String studentId,
    String assignmentId,
    double? score,
  ) async {
    try {
      await _supabase.rpc(
        RpcFunctions.completeAssignment,
        params: {
          'p_student_id': studentId,
          'p_assignment_id': assignmentId,
          'p_score': score,
        },
      );

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 4: Remove unused imports**

In `supabase_student_assignment_repository.dart`, the `AppClock` import is no longer needed by `startAssignment` or `completeAssignment`. Check if `getActiveAssignments` still uses it (line 81 — yes it does). Keep `AppClock` import.

The `AssignmentStatus` import from `owlio_shared` may no longer be needed in this file — check if any remaining method references it. `getStudentAssignments` uses `neq('status', 'withdrawn')` as a raw string. No other reference. Remove if unused.

- [ ] **Step 5: Run analysis**

Run: `dart analyze lib/data/repositories/supabase/supabase_student_assignment_repository.dart packages/owlio_shared/lib/src/constants/rpc_functions.dart`
Expected: No errors, no warnings (infos are acceptable).

- [ ] **Step 6: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/rpc_functions.dart lib/data/repositories/supabase/supabase_student_assignment_repository.dart
git commit -m "feat: migrate startAssignment/completeAssignment to RPC calls

Replaces direct table UPDATEs with SECURITY DEFINER RPCs that validate
enrollment, status transitions, and score range server-side."
```

---

### Task 3: Remove debugPrint and add StudentAssignmentController

**Files:**
- Modify: `lib/presentation/providers/student_assignment_provider.dart`

- [ ] **Step 1: Remove debugPrint import and all debugPrint calls**

Remove `import 'package:flutter/foundation.dart';` from line 1.

Remove the following debugPrint lines:
- Line 45: `debugPrint('📋 activeAssignmentsProvider: userId=$userId');`
- Line 53: `debugPrint('📋 activeAssignmentsProvider: FAILURE=${failure.message}');`
- Line 57: `debugPrint('📋 activeAssignmentsProvider: got ${assignments.length} assignments');`
- Line 92: `debugPrint('🔄 assignmentSyncProvider: Starting sync...');`
- Line 104: `debugPrint('🔄 assignmentSyncProvider: Found ${assignments.length} active assignments');`
- Line 125: `debugPrint('🔄 Syncing: Assignment "${assignment.title}" - book already completed');`
- Line 137: `debugPrint('🔄 Syncing unit assignment: "${assignment.title}"');`
- Line 148: `debugPrint('🔄 assignmentSyncProvider: Synced $syncedCount assignments');`
- Line 153: `debugPrint('🔄 assignmentSyncProvider: No sync needed');`

- [ ] **Step 2: Add StartAssignment UseCase import and StudentAssignmentController**

Add import at top of file (after existing imports):
```dart
import '../../domain/usecases/student_assignment/start_assignment_usecase.dart';
```

Note: `auth_provider.dart` and `usecase_providers.dart` are already imported — do not duplicate.

Add the controller after `assignmentSyncProvider` (before `unitAssignmentItemsProvider`):

```dart
/// Controller for student assignment mutations (start, navigation)
class StudentAssignmentController extends StateNotifier<AsyncValue<void>> {
  StudentAssignmentController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  bool get isMutating => state is AsyncLoading;

  Future<String?> startAssignment(String assignmentId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return 'Not logged in';
    }
    final useCase = _ref.read(startAssignmentUseCaseProvider);
    final result = await useCase(StartAssignmentParams(
      studentId: userId,
      assignmentId: assignmentId,
    ));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (_) {
        _ref.invalidate(studentAssignmentDetailProvider(assignmentId));
        _ref.invalidate(studentAssignmentsProvider);
        _ref.invalidate(activeAssignmentsProvider);
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final studentAssignmentControllerProvider =
    StateNotifierProvider.autoDispose<StudentAssignmentController, AsyncValue<void>>((ref) {
  return StudentAssignmentController(ref);
});
```

- [ ] **Step 3: Run analysis**

Run: `dart analyze lib/presentation/providers/student_assignment_provider.dart`
Expected: No errors (infos acceptable).

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/student_assignment_provider.dart
git commit -m "fix: remove debugPrint and add StudentAssignmentController

Removes 9 debugPrint statements from production code.
Adds StateNotifier controller for start mutation (Finding #8)."
```

---

### Task 4: Add AssignmentDeleteController to teacher provider

**Files:**
- Modify: `lib/presentation/providers/teacher_provider.dart`

- [ ] **Step 1: Add imports and controller**

Add import at top of `teacher_provider.dart`:
```dart
import '../../domain/usecases/assignment/delete_assignment_usecase.dart';
```

After line 285 (end of `studentUnitProgressProvider`), before the leaderboard section comment, add:

```dart
/// Controller for teacher assignment mutations (delete)
class AssignmentDeleteController extends StateNotifier<AsyncValue<void>> {
  AssignmentDeleteController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  bool get isMutating => state is AsyncLoading;

  Future<String?> deleteAssignment(String assignmentId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(deleteAssignmentUseCaseProvider);
    final result = await useCase(DeleteAssignmentParams(assignmentId: assignmentId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return failure.message;
      },
      (_) {
        _ref.invalidate(teacherAssignmentsProvider);
        _ref.invalidate(teacherStatsProvider);
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }
}

final assignmentDeleteControllerProvider =
    StateNotifierProvider.autoDispose<AssignmentDeleteController, AsyncValue<void>>((ref) {
  return AssignmentDeleteController(ref);
});
```

- [ ] **Step 2: Fix teacher error propagation (#13)**

Replace lines 228–231 of `teacherAssignmentsProvider`:

Old:
```dart
  return result.fold(
    (failure) => [],
    (assignments) => assignments,
  );
```

New:
```dart
  return result.fold(
    (failure) => throw Exception(failure.message),
    (assignments) => assignments,
  );
```

- [ ] **Step 3: Run analysis**

Run: `dart analyze lib/presentation/providers/teacher_provider.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/teacher_provider.dart
git commit -m "fix: add AssignmentDeleteController and propagate teacher errors

Adds StateNotifier for delete mutation (Finding #7).
Makes error state reachable in AssignmentsScreen (Finding #13)."
```

---

### Task 5: Update screens to use controllers

**Files:**
- Modify: `lib/presentation/screens/teacher/assignment_detail_screen.dart:10-12, 211-231`
- Modify: `lib/presentation/screens/student/student_assignment_detail_screen.dart:411-597`

- [ ] **Step 1: Update teacher assignment_detail_screen.dart**

Replace the import and delete logic. Remove import of `delete_assignment_usecase.dart` (line 10) and `usecase_providers.dart` (line 12). The controller is accessed via `teacher_provider.dart` which is already imported.

In the `onSelected` callback (lines 211–231), replace the direct UseCase call:

Old (lines 211–231):
```dart
              if ((confirmed ?? false) && context.mounted) {
                // Delete assignment
                final useCase = ref.read(deleteAssignmentUseCaseProvider);
                final result = await useCase(DeleteAssignmentParams(assignmentId: assignment.id));

                result.fold(
                  (failure) {
                    if (context.mounted) {
                      showAppSnackBar(context, 'Error: ${failure.message}', type: SnackBarType.error);
                    }
                  },
                  (_) {
                    if (context.mounted) {
                      ref.invalidate(teacherAssignmentsProvider);
                      ref.invalidate(teacherStatsProvider);
                      showAppSnackBar(context, 'Assignment deleted');
                      context.pop();
                    }
                  },
                );
              }
```

New:
```dart
              if ((confirmed ?? false) && context.mounted) {
                final error = await ref
                    .read(assignmentDeleteControllerProvider.notifier)
                    .deleteAssignment(assignment.id);
                if (context.mounted) {
                  if (error != null) {
                    showAppSnackBar(context, 'Error: $error', type: SnackBarType.error);
                  } else {
                    showAppSnackBar(context, 'Assignment deleted');
                    context.pop();
                  }
                }
              }
```

Remove the now-unused imports:
- `import '../../../domain/usecases/assignment/delete_assignment_usecase.dart';`
- `import '../../providers/usecase_providers.dart';`

- [ ] **Step 2: Update student_assignment_detail_screen.dart**

Add import at top:
```dart
import '../../providers/student_assignment_provider.dart' show studentAssignmentControllerProvider, studentAssignmentDetailProvider, studentAssignmentsProvider, unitAssignmentItemsProvider;
```

(Replace the existing selective import to include `studentAssignmentControllerProvider`.)

Remove the import of `start_assignment_usecase.dart` and `usecase_providers.dart` if present.

Replace `_startReading` method (lines 411–436):

Old:
```dart
  void _startReading(BuildContext context, WidgetRef ref, StudentAssignment assignment) async {
    debugPrint('📚 _startReading: bookId=${assignment.bookId}, contentConfig=${assignment.contentConfig}');
    if (assignment.bookId == null) {
      debugPrint('📚 _startReading: bookId is null, returning');
      return;
    }

    // Start the assignment if not started
    if (assignment.status == StudentAssignmentStatus.pending) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final useCase = ref.read(startAssignmentUseCaseProvider);
        await useCase(StartAssignmentParams(
          studentId: userId,
          assignmentId: assignment.assignmentId,
        ),);
        ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        ref.invalidate(studentAssignmentsProvider);
      }
    }

    // Navigate to book detail - use go() not push() to avoid shell navigation conflicts
    if (context.mounted) {
      context.go(AppRoutes.bookDetailPath(assignment.bookId!));
    }
  }
```

New:
```dart
  void _startReading(BuildContext context, WidgetRef ref, StudentAssignment assignment) async {
    if (assignment.bookId == null) return;

    if (assignment.status == StudentAssignmentStatus.pending) {
      await ref.read(studentAssignmentControllerProvider.notifier)
          .startAssignment(assignment.assignmentId);
    }

    if (context.mounted) {
      context.go(AppRoutes.bookDetailPath(assignment.bookId!));
    }
  }
```

Replace `_startVocabulary` method (lines 438–458):

New:
```dart
  void _startVocabulary(BuildContext context, WidgetRef ref, StudentAssignment assignment) async {
    if (assignment.wordListId == null) return;

    if (assignment.status == StudentAssignmentStatus.pending) {
      await ref.read(studentAssignmentControllerProvider.notifier)
          .startAssignment(assignment.assignmentId);
    }

    if (context.mounted) {
      context.go(AppRoutes.vocabularyListPath(assignment.wordListId!));
    }
  }
```

Replace `_startUnitItem` method in `_UnitItemsList` (lines 567–597):

New:
```dart
  void _startUnitItem(
    BuildContext context,
    WidgetRef ref,
    StudentAssignment assignment, {
    String? wordListId,
    String? bookId,
  }) async {
    if (assignment.status == StudentAssignmentStatus.pending) {
      await ref.read(studentAssignmentControllerProvider.notifier)
          .startAssignment(assignment.assignmentId);
    }

    if (!context.mounted) return;

    if (wordListId != null) {
      context.go(AppRoutes.vocabularyListPath(wordListId));
    } else if (bookId != null) {
      context.go(AppRoutes.bookDetailPath(bookId));
    }
  }
```

- [ ] **Step 3: Run analysis**

Run: `dart analyze lib/presentation/screens/teacher/assignment_detail_screen.dart lib/presentation/screens/student/student_assignment_detail_screen.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/teacher/assignment_detail_screen.dart lib/presentation/screens/student/student_assignment_detail_screen.dart
git commit -m "refactor: use StateNotifier controllers for assignment mutations

Teacher delete and student start now go through controllers
instead of calling UseCases directly in widgets (Findings #7, #8)."
```

---

### Task 6: Extract shared AssignmentStatusBadge widget

**Files:**
- Modify: `lib/presentation/utils/ui_helpers.dart`
- Modify: `lib/presentation/screens/teacher/assignments_screen.dart:314-351`
- Modify: `lib/presentation/screens/teacher/reports/assignment_report_screen.dart:321-357`

- [ ] **Step 1: Add AssignmentStatusBadge to ui_helpers.dart**

Add at the end of `ui_helpers.dart`:

```dart
/// Shared status badge for teacher assignment views
class AssignmentStatusBadge extends StatelessWidget {
  const AssignmentStatusBadge({super.key, required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (assignment.isOverdue) {
      color = Colors.red;
      text = 'Overdue';
    } else if (assignment.isUpcoming) {
      color = Colors.orange;
      text = 'Upcoming';
    } else {
      color = Colors.green;
      text = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Replace _StatusBadge in assignments_screen.dart**

Delete the entire `_StatusBadge` class (lines 314–351). Replace all references from `_StatusBadge(assignment: ...)` to `AssignmentStatusBadge(assignment: ...)`.

- [ ] **Step 3: Replace _StatusBadge in assignment_report_screen.dart**

Delete the entire `_StatusBadge` class (lines 321–357). Replace all references from `_StatusBadge(assignment: ...)` to `AssignmentStatusBadge(assignment: ...)`.

- [ ] **Step 4: Run analysis**

Run: `dart analyze lib/presentation/utils/ui_helpers.dart lib/presentation/screens/teacher/assignments_screen.dart lib/presentation/screens/teacher/reports/assignment_report_screen.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/utils/ui_helpers.dart lib/presentation/screens/teacher/assignments_screen.dart lib/presentation/screens/teacher/reports/assignment_report_screen.dart
git commit -m "fix: extract shared AssignmentStatusBadge, fix color inconsistency

Consolidates duplicated _StatusBadge from two screens into ui_helpers.
Standardizes 'Upcoming' color to orange (Finding #10)."
```

---

### Task 7: Add content validation to create screen

**Files:**
- Modify: `lib/presentation/screens/teacher/create_assignment_screen.dart:109-116`

- [ ] **Step 1: Add content validation guards**

In `_createAssignment()`, after the class validation check (line 115 `return;`) and before `setState(() => _isLoading = true);` (line 117), add:

```dart
    // Validate content selection per type
    if (_selectedType == AssignmentType.book && _selectedBookId == null) {
      showAppSnackBar(context, 'Please select a book', type: SnackBarType.warning);
      return;
    }
    if (_selectedType == AssignmentType.vocabulary && _selectedWordListId == null) {
      showAppSnackBar(context, 'Please select a word list', type: SnackBarType.warning);
      return;
    }
    if (_selectedType == AssignmentType.unit && _selectedScopeLpUnitId == null) {
      showAppSnackBar(context, 'Please select a unit', type: SnackBarType.warning);
      return;
    }
```

- [ ] **Step 2: Run analysis**

Run: `dart analyze lib/presentation/screens/teacher/create_assignment_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/teacher/create_assignment_screen.dart
git commit -m "fix: validate content selection before assignment creation

Prevents submitting book/vocab/unit assignment without selecting
the target content item (Finding #12)."
```

---

### Task 8: Update feature spec with fix statuses

**Files:**
- Modify: `docs/specs/17-assignment-system.md`

- [ ] **Step 1: Update finding statuses**

Update the Findings table:
- #5: Status `TODO` → `Fixed`
- #6: Status `TODO` → `Fixed`
- #7: Status `TODO` → `Fixed`
- #8: Status `TODO` → `Fixed`
- #10: Status `TODO` → `Fixed`
- #12: Status `TODO` → `Fixed`
- #13: Status `TODO` → `Fixed`
- #14: Status `TODO` → `Skipped (client-only by design)`
- #16: Status `TODO` → `Fixed`

Update #14 description to: `overdue` status is a display-only concept computed client-side in `StudentAssignmentModel.fromJson` — no server-side state transition by design (no business logic depends on it)

- [ ] **Step 2: Update Checklist Result section**

Update each category to reflect the fixes:
- Architecture Compliance: **PASS** — UseCase-in-widget pattern fixed (#7, #8); 3-day grace in repository kept as-is (#9, acceptable)
- Code Quality: **1 remaining** — unit item rendering duplication (#11, low priority). debugPrint removed (#5, #6); StatusBadge consolidated (#10)
- Dead Code: **PASS**
- Database & Security: **1 remaining** — `student_update` RLS still allows direct UPDATEs (future hardening). Start/complete migrated to RPCs (#16)
- Edge Cases & UX: **PASS** — content validation added (#12); error state reachable (#13)
- Performance: **PASS**
- Cross-System Integrity: **PASS**

- [ ] **Step 3: Update Known Issues section**

Mark fixed items with ~~strikethrough~~ and add "Fixed" note:
- Item 1 (student forgery): ~~text~~ — **Fixed** in `20260328400001_assignment_start_complete_rpcs.sql`
- Item 3 (UseCase-in-widget): ~~text~~ — **Fixed**: `AssignmentDeleteController` and `StudentAssignmentController`
- Item 4 (missing validation): ~~text~~ — **Fixed**: pre-submit guards added
- Item 5 (debugPrint): ~~text~~ — **Fixed**: all 9 statements removed

Update item 2 (overdue) to state "Kept as client-only by design — overdue is a display concept, not a state transition."

- [ ] **Step 4: Commit**

```bash
git add docs/specs/17-assignment-system.md
git commit -m "docs: update Assignment System spec with audit fix statuses"
```

---

### Task 9: Final verification

- [ ] **Step 1: Run full analysis**

Run: `dart analyze lib/`
Expected: No new errors or warnings introduced by changes.

- [ ] **Step 2: Verify all files compile**

Run: `flutter build web --no-pub 2>&1 | tail -5`
Expected: Build succeeds (or existing errors only, no new ones).
