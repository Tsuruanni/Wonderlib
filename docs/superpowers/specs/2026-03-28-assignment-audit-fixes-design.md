# Assignment System Audit Fixes — Design

Source: `docs/specs/17-assignment-system.md` audit findings #5–#16 (17 total, 4 already fixed).

## Decision Summary

| # | Finding | Approach | Complexity |
|---|---------|----------|------------|
| 5 | debugPrint in `activeAssignmentsProvider` | Remove | Trivial |
| 6 | debugPrint in `assignmentSyncProvider` | Remove | Trivial |
| 7 | Delete UseCase called in widget (`assignment_detail_screen.dart`) | Extract to StateNotifier controller | Medium |
| 8 | Start UseCase called in widget (`student_assignment_detail_screen.dart`) | Extract to StateNotifier controller | Medium |
| 9 | 3-day overdue grace in repository | Keep as-is, document in spec | None |
| 10 | `_StatusBadge` duplicated (assignments_screen vs report_screen) | Extract to `ui_helpers.dart` | Trivial |
| 11 | Unit item type rendering duplicated in 3 places | Extract shared widget | Low |
| 12 | Missing content validation on create screen | Add pre-submit guards | Low |
| 13 | Teacher list error state unreachable | Propagate error from provider | Low |
| 14 | `overdue` never set server-side | Keep client-only, document as "by design" | None |
| 16 | Student can forge start/complete via direct UPDATE | Migrate to SECURITY DEFINER RPCs (basic validation) | High |
| 17 | Silent enum fallbacks | Keep as-is (codebase-wide pattern) | None |

Skipped (no action): #9, #14, #15, #17.

## Phase 1: Security — RPC Migration (#16)

### Problem

`startAssignment` and `completeAssignment` in `supabase_student_assignment_repository.dart` use direct `.update()` on `assignment_students`. RLS allows students to UPDATE their own rows, so a student with API access can set `status='completed', score=100, progress=100`.

### Design: Two new SECURITY DEFINER RPCs

**`start_assignment(p_student_id UUID, p_assignment_id UUID)`**

Validation:
1. `auth.uid() = p_student_id` — identity check
2. Row exists in `assignment_students` with matching IDs
3. Current status is `pending` — can't re-start a completed/withdrawn assignment
4. Assignment's `start_date <= now()` — can't start before it's available

Mutations:
- `status = 'in_progress'`
- `started_at = now()`

Returns: void.

**`complete_assignment(p_student_id UUID, p_assignment_id UUID, p_score DECIMAL DEFAULT NULL)`**

Validation:
1. `auth.uid() = p_student_id` — identity check
2. Row exists in `assignment_students` with matching IDs
3. Current status is `pending` or `in_progress` — idempotent if already `completed`
4. Status is not `withdrawn`
5. Score is NULL or between 0 and 100

Mutations:
- `status = 'completed'`
- `progress = 100`
- `score = p_score` (client-supplied, not server-derived — see Decision below)
- `completed_at = now()`

Returns: void.

### Decision: Client-supplied score (Option B)

- Assignment completion does NOT award XP/coins/badges — those come from the underlying activities
- Full server-side score derivation (Option A) would require per-type logic (book: reading_progress, vocab: session_results, unit: already has its own RPC) — disproportionate complexity
- Teacher can cross-check scores against reading progress and vocab stats independently
- Basic validation ensures valid state transitions (can't skip `pending → completed` without going through `in_progress`, can't complete a `withdrawn` assignment). The real guard against "mark done without doing work" is that completion is triggered by content providers (book_provider, vocabulary_provider), not by the student directly — the RPC formalizes this but doesn't add content-level verification.

### Migration file

`supabase/migrations/20260328000001_assignment_start_complete_rpcs.sql`:
- `CREATE OR REPLACE FUNCTION start_assignment(...)` — SECURITY DEFINER
- `CREATE OR REPLACE FUNCTION complete_assignment(...)` — SECURITY DEFINER
- Add constants to `RpcFunctions`: `startAssignment`, `completeAssignment`

### Repository changes

`supabase_student_assignment_repository.dart`:
- `startAssignment()`: replace `.update()` with `_supabase.rpc(RpcFunctions.startAssignment, params: {...})`
- `completeAssignment()`: replace `.update()` with `_supabase.rpc(RpcFunctions.completeAssignment, params: {...})`

### RLS consideration

The `assignment_students_student_update` policy currently allows students to UPDATE their own rows. After migration:
- Direct UPDATEs from client will still be allowed by RLS — the `assignment_students_student_update` policy exists and `update_assignment_progress` RPC also relies on it indirectly
- But the repository no longer uses direct UPDATEs for start/complete — all mutations go through RPCs
- A determined attacker could still use the Supabase JS client to issue direct UPDATEs
- **Future hardening**: Move ALL student-facing mutations to RPCs and drop the `student_update` policy entirely. Out of scope for this fix.

## Phase 2: Client-Side Fixes (#5–#13)

### #5, #6: debugPrint removal

Remove all 9 `debugPrint` statements in `student_assignment_provider.dart`. These are the only assignment-specific debug prints; other files' debugPrints are out of scope.

### #7: Teacher delete → StateNotifier

Create `AssignmentDeleteController` (StateNotifier) in `teacher_provider.dart`:

```dart
class AssignmentDeleteController extends StateNotifier<AsyncValue<void>> {
  AssignmentDeleteController(this._ref) : super(const AsyncValue.data(null));

  Future<String?> deleteAssignment(String assignmentId) async {
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
```

`assignment_detail_screen.dart` calls `ref.read(assignmentDeleteControllerProvider.notifier).deleteAssignment(id)` instead of calling the UseCase directly.

### #8: Student start → StateNotifier

Create `StudentAssignmentController` (StateNotifier) in `student_assignment_provider.dart`:

```dart
class StudentAssignmentController extends StateNotifier<AsyncValue<void>> {
  StudentAssignmentController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<String?> startAssignment(String assignmentId) async {
    state = const AsyncValue.loading();
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return 'Not logged in';
    }
    final useCase = _ref.read(startAssignmentUseCaseProvider);
    final result = await useCase(StartAssignmentParams(
      studentId: userId, assignmentId: assignmentId,
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
```

`student_assignment_detail_screen.dart` calls controller methods instead of UseCase directly. Covers `_startReading`, `_startVocabulary`, `_startUnitItem`.

### #10: StatusBadge extraction

Add to `ui_helpers.dart`:

```dart
class AssignmentStatusBadge extends StatelessWidget {
  const AssignmentStatusBadge({required this.assignment});
  final Assignment assignment;
  // Uses orange for Upcoming (consistent with assignments_screen)
}
```

Replace both `_StatusBadge` widgets in `assignments_screen.dart` and `assignment_report_screen.dart`.

### #11: Unit item widget extraction

Create shared widget in `lib/presentation/widgets/common/learning_path_item_tile.dart`:

```dart
class LearningPathItemTile extends StatelessWidget {
  const LearningPathItemTile({required this.itemType, required this.itemName, ...});
  // Unified switch-case rendering for LearningPathItemType
}
```

Replace in 3 locations: create screen `_UnitItemRow`, teacher detail `_UnitContentSection`, student detail `_UnitItemsList`.

### #12: Content validation on create

Add pre-submit guards in `_createAssignment()`:

```dart
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

### #13: Teacher error propagation

Change `teacherAssignmentsProvider` to propagate errors instead of swallowing:

```dart
final teacherAssignmentsProvider = FutureProvider<List<Assignment>>((ref) async {
  // ... existing code ...
  return result.fold(
    (failure) => throw Exception(failure.message),  // was: return []
    (assignments) => assignments,
  );
});
```

This makes the `.when(error: ...)` branch in `assignments_screen.dart` reachable.

### #14: Overdue — document as client-only

Update `docs/specs/17-assignment-system.md` Finding #14 status from `TODO` to `Skipped (client-only by design)`. Add note to Business Rules explaining that overdue is a display-only concept with no server-side state transition.

## Build Sequence

1. **Phase 1**: DB migration (start_assignment + complete_assignment RPCs) → shared package constants → repository changes → test
2. **Phase 2**: All client-side fixes in parallel (debugPrint, controllers, widgets, validation, error propagation)
3. **Phase 3**: Update `docs/specs/17-assignment-system.md` with fix statuses
