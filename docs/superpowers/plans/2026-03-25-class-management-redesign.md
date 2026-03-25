# Class Management Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Classes tab into a dedicated management tool with class edit/delete, student password viewing, and bulk student transfer. Separate management from reporting via a mode flag on ClassDetailScreen.

**Architecture:** 5 tasks. Task 1: DB migrations (RPCs). Task 2: Backend chain (repo + usecases + providers). Task 3: Classes list screen (edit/delete menu). Task 4: Class detail screen rewrite (management mode + select mode). Task 5: Router + report mode integration.

**Tech Stack:** PostgreSQL, Flutter, Riverpod, Supabase

**Spec:** `docs/superpowers/specs/2026-03-25-class-management-redesign.md`

---

## Task 1: Database Migrations — New RPCs

**Files:**
- Create: `supabase/migrations/20260325000014_class_management_rpcs.sql`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Write the migration**

```sql
-- =============================================
-- Class Management RPCs
-- 1. delete_class — safe delete (only if no students)
-- 2. bulk_move_students — atomic multi-student transfer
-- 3. update_class — edit class name/description
-- 4. Modify get_students_in_class — add password_plain
-- =============================================

-- 1. Safe class deletion
CREATE OR REPLACE FUNCTION delete_class(p_class_id UUID)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
  v_student_count INT;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_class_school_id
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_class_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: class is not in your school';
  END IF;

  SELECT COUNT(*)::INT INTO v_student_count
  FROM profiles pr WHERE pr.class_id = p_class_id AND pr.role = 'student';

  IF v_student_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete class with % students. Move all students first.', v_student_count;
  END IF;

  DELETE FROM classes WHERE classes.id = p_class_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Atomic bulk student transfer
CREATE OR REPLACE FUNCTION bulk_move_students(
  p_student_ids UUID[],
  p_target_class_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_target_school_id UUID;
  v_invalid_count INT;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  -- Verify target class is in caller's school
  SELECT cl.school_id INTO v_target_school_id
  FROM classes cl WHERE cl.id = p_target_class_id;

  IF v_target_school_id IS NULL THEN
    RAISE EXCEPTION 'Target class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_target_school_id THEN
    RAISE EXCEPTION 'Unauthorized: target class is not in your school';
  END IF;

  -- Verify all students are in caller's school
  SELECT COUNT(*)::INT INTO v_invalid_count
  FROM profiles pr
  WHERE pr.id = ANY(p_student_ids)
    AND (pr.school_id IS DISTINCT FROM v_caller_school_id OR pr.role != 'student');

  IF v_invalid_count > 0 THEN
    RAISE EXCEPTION 'Some students are not in your school';
  END IF;

  -- Atomic move
  UPDATE profiles SET class_id = p_target_class_id
  WHERE profiles.id = ANY(p_student_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update class name/description
CREATE OR REPLACE FUNCTION update_class(
  p_class_id UUID,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_class_school_id
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_class_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: class is not in your school';
  END IF;

  UPDATE classes SET name = p_name, description = p_description
  WHERE classes.id = p_class_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Add password_plain to get_students_in_class
DROP FUNCTION IF EXISTS get_students_in_class(UUID);
CREATE OR REPLACE FUNCTION get_students_in_class(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  first_name TEXT,
  last_name TEXT,
  student_number TEXT,
  email TEXT,
  avatar_url TEXT,
  password_plain TEXT,
  xp INT,
  level INT,
  streak INT,
  books_read INT,
  avg_progress NUMERIC
) AS $$
DECLARE
  v_caller_school_id UUID;
  v_class_school_id UUID;
BEGIN
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  SELECT pr.school_id INTO v_caller_school_id
  FROM profiles pr WHERE pr.id = auth.uid();

  SELECT cl.school_id INTO v_class_school_id
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: cannot access students from another school';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name::TEXT,
    p.last_name::TEXT,
    p.student_number::TEXT,
    u.email::TEXT,
    p.avatar_url::TEXT,
    p.password_plain::TEXT,
    p.xp,
    p.level,
    p.current_streak,
    COALESCE((
      SELECT COUNT(DISTINCT rp.book_id)::INT
      FROM reading_progress rp
      WHERE rp.user_id = p.id AND rp.is_completed = true
    ), 0) as books_read,
    COALESCE((
      SELECT AVG(rp2.completion_percentage)
      FROM reading_progress rp2
      WHERE rp2.user_id = p.id
    ), 0) as avg_progress
  FROM profiles p
  LEFT JOIN auth.users u ON p.id = u.id
  WHERE p.class_id = p_class_id
  ORDER BY p.last_name, p.first_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Add RPC constants**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, add in Teacher section:
```dart
static const deleteClass = 'delete_class';
static const bulkMoveStudents = 'bulk_move_students';
static const updateClass = 'update_class';
```

- [ ] **Step 3: Push migration**

Run: `supabase db push --dry-run && supabase db push`

- [ ] **Step 4: Commit**

```
feat(db): class management RPCs — delete, bulk move, update, password_plain

- delete_class: safe delete with student count check
- bulk_move_students: atomic multi-student transfer
- update_class: edit name/description
- get_students_in_class: add password_plain to return columns
```

---

## Task 2: Backend Chain — Repo + UseCases + Providers

**Files:**
- Modify: `lib/domain/entities/teacher.dart` (add `passwordPlain` to `StudentSummary`)
- Modify: `lib/data/models/teacher/student_summary_model.dart` (read `password_plain`)
- Modify: `lib/domain/repositories/teacher_repository.dart` (add 3 methods)
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart` (implement 3 methods)
- Create: `lib/domain/usecases/teacher/update_class_usecase.dart`
- Create: `lib/domain/usecases/teacher/delete_class_usecase.dart`
- Create: `lib/domain/usecases/teacher/bulk_move_students_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart` (register 3 providers)

- [ ] **Step 1: Add `passwordPlain` to StudentSummary entity**

In `lib/domain/entities/teacher.dart`, add to `StudentSummary`:
```dart
// Add field in constructor
this.passwordPlain,

// Add field declaration
final String? passwordPlain;

// Add to props
passwordPlain,
```

- [ ] **Step 2: Update StudentSummaryModel**

In `lib/data/models/teacher/student_summary_model.dart`:
- Add `this.passwordPlain` to constructor
- Add `passwordPlain: json['password_plain'] as String?,` in `fromJson`
- Add `final String? passwordPlain;` field
- Add `passwordPlain: entity.passwordPlain,` in `fromEntity`
- Add `'password_plain': passwordPlain,` in `toJson`
- Add `passwordPlain: passwordPlain,` in `toEntity`

- [ ] **Step 3: Add 3 methods to TeacherRepository interface**

In `lib/domain/repositories/teacher_repository.dart`, add before the closing `}`:
```dart
  /// Update class name and description
  Future<Either<Failure, void>> updateClass({
    required String classId,
    required String name,
    String? description,
  });

  /// Delete a class (must have no students)
  Future<Either<Failure, void>> deleteClass(String classId);

  /// Move multiple students to a target class atomically
  Future<Either<Failure, void>> bulkMoveStudents({
    required List<String> studentIds,
    required String targetClassId,
  });
```

- [ ] **Step 4: Implement in SupabaseTeacherRepository**

Add 3 methods using RPC calls (same pattern as existing methods):
```dart
@override
Future<Either<Failure, void>> updateClass({
  required String classId,
  required String name,
  String? description,
}) async {
  try {
    await _supabase.rpc(RpcFunctions.updateClass, params: {
      'p_class_id': classId,
      'p_name': name,
      'p_description': description,
    });
    return const Right(null);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}

@override
Future<Either<Failure, void>> deleteClass(String classId) async {
  try {
    await _supabase.rpc(RpcFunctions.deleteClass, params: {
      'p_class_id': classId,
    });
    return const Right(null);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}

@override
Future<Either<Failure, void>> bulkMoveStudents({
  required List<String> studentIds,
  required String targetClassId,
}) async {
  try {
    await _supabase.rpc(RpcFunctions.bulkMoveStudents, params: {
      'p_student_ids': studentIds,
      'p_target_class_id': targetClassId,
    });
    return const Right(null);
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

- [ ] **Step 5: Create 3 usecases**

`lib/domain/usecases/teacher/update_class_usecase.dart`:
```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class UpdateClassUseCase implements UseCase<void, UpdateClassParams> {
  const UpdateClassUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(UpdateClassParams params) {
    return _repository.updateClass(
      classId: params.classId,
      name: params.name,
      description: params.description,
    );
  }
}

class UpdateClassParams {
  const UpdateClassParams({required this.classId, required this.name, this.description});
  final String classId;
  final String name;
  final String? description;
}
```

`lib/domain/usecases/teacher/delete_class_usecase.dart`:
```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class DeleteClassUseCase implements UseCase<void, DeleteClassParams> {
  const DeleteClassUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(DeleteClassParams params) {
    return _repository.deleteClass(params.classId);
  }
}

class DeleteClassParams {
  const DeleteClassParams({required this.classId});
  final String classId;
}
```

`lib/domain/usecases/teacher/bulk_move_students_usecase.dart`:
```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class BulkMoveStudentsUseCase implements UseCase<void, BulkMoveStudentsParams> {
  const BulkMoveStudentsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, void>> call(BulkMoveStudentsParams params) {
    return _repository.bulkMoveStudents(
      studentIds: params.studentIds,
      targetClassId: params.targetClassId,
    );
  }
}

class BulkMoveStudentsParams {
  const BulkMoveStudentsParams({required this.studentIds, required this.targetClassId});
  final List<String> studentIds;
  final String targetClassId;
}
```

- [ ] **Step 6: Register providers**

In `lib/presentation/providers/usecase_providers.dart`, add in teacher section:
```dart
final updateClassUseCaseProvider = Provider((ref) {
  return UpdateClassUseCase(ref.watch(teacherRepositoryProvider));
});

final deleteClassUseCaseProvider = Provider((ref) {
  return DeleteClassUseCase(ref.watch(teacherRepositoryProvider));
});

final bulkMoveStudentsUseCaseProvider = Provider((ref) {
  return BulkMoveStudentsUseCase(ref.watch(teacherRepositoryProvider));
});
```

Add imports for the 3 new usecases.

- [ ] **Step 7: Run dart analyze**

Run: `dart analyze lib/`

- [ ] **Step 8: Commit**

```
feat(teacher): backend chain for class management — update, delete, bulk move

- Add passwordPlain to StudentSummary entity + model
- 3 new repository methods + usecase + provider registrations
- updateClass, deleteClass, bulkMoveStudents
```

---

## Task 3: Classes List Screen — Edit/Delete Menu

**Files:**
- Modify: `lib/presentation/screens/teacher/classes_screen.dart`

- [ ] **Step 1: Read the full file first**

- [ ] **Step 2: Remove avg progress from _ClassCard**

In `_ClassCard`, remove the color-coded progress percentage text and `ScoreColors.getProgressColor` usage. Keep: class name, grade avatar, student count, academic year.

- [ ] **Step 3: Add 3-dot popup menu to each class card**

Add a `PopupMenuButton` with "Edit" and "Delete" options. Delete is only enabled when `classItem.studentCount == 0`.

"Edit" → `_showEditClassDialog(context, ref, classItem)` — same pattern as `_showCreateClassDialog` but pre-filled with current name/description.

"Delete" → confirmation dialog → `deleteClassUseCaseProvider` → invalidate `currentTeacherClassesProvider`.

- [ ] **Step 4: Implement `_showEditClassDialog`**

Dialog with pre-filled name + description fields. On save:
```dart
final useCase = ref.read(updateClassUseCaseProvider);
final result = await useCase(UpdateClassParams(
  classId: classItem.id,
  name: nameController.text.trim(),
  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
));
// On success: invalidate currentTeacherClassesProvider + SnackBar
```

- [ ] **Step 5: Implement delete action**

```dart
final useCase = ref.read(deleteClassUseCaseProvider);
final result = await useCase(DeleteClassParams(classId: classItem.id));
// On success: invalidate + SnackBar
// On failure: SnackBar with error (likely "Cannot delete class with X students")
```

- [ ] **Step 6: Run dart analyze**

- [ ] **Step 7: Commit**

```
feat(teacher): class list with edit/delete, remove avg progress

- Remove stats from class cards (management view, not reports)
- Add popup menu: edit class name/description, delete empty class
```

---

## Task 4: Class Detail Screen Rewrite — Management Mode

This is the largest task. The `ClassDetailScreen` gets a `mode` parameter and the management mode gets a complete UX overhaul.

**Files:**
- Modify: `lib/presentation/screens/teacher/class_detail_screen.dart` (major rewrite)

- [ ] **Step 1: Read the full current file**

- [ ] **Step 2: Add mode enum and constructor parameter**

```dart
enum ClassDetailMode { management, report }

class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.classId,
    this.mode = ClassDetailMode.management,
  });

  final String classId;
  final ClassDetailMode mode;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}
```

Change from `ConsumerWidget` to `ConsumerStatefulWidget` because we need `_isSelectMode` and `_selectedStudentIds` state.

- [ ] **Step 3: Implement state**

```dart
class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  bool _isSelectMode = false;
  final Set<String> _selectedStudentIds = {};
```

- [ ] **Step 4: Build method with mode branching**

AppBar:
- Management mode: title = class name (from provider or passed), action = "Select" toggle IconButton
- Report mode: title = "Class Students", no select action

Body:
- Management mode: NO stats bar, student list with management cards
- Report mode: stats bar (existing `_ClassStatsBar`), student list with report cards

- [ ] **Step 5: Management mode student card**

Simplified card: avatar, full name, student number, level badge. No XP/streak/books mini-stats. No 3-dot menu.

Tap → show `_StudentInfoSheet` bottom sheet:
- Student name, student number
- Email (tap to copy)
- Password (if `passwordPlain` != null, show with eye icon toggle)
- "View Full Profile" button → navigate to student detail

- [ ] **Step 6: Select mode UX**

When `_isSelectMode == true`:
- Each student card gets a leading `Checkbox`
- Bottom of screen: floating `Material` bar with "X selected — Move to..." button
- "Move to..." → `_showMoveToSheet(context, ref)`:
  - Bottom sheet with list of classes (from `currentTeacherClassesProvider`, excluding current)
  - Tap target class → confirmation → `bulkMoveStudentsUseCaseProvider` → invalidate + exit select mode

- [ ] **Step 7: Report mode student card**

Keep existing card with XP/streak/books mini-stats. Tap → navigate to student detail. No bottom sheet, no select mode.

- [ ] **Step 8: Remove old code**

Delete: `_showActionsSheet`, `_sendPasswordResetEmail`, `_generateNewPassword`, `_showChangeClassDialog`, `_changeClass`. These are replaced by the new UX.

Keep `_ClassStatsBar`, `_StatItem`, `_MiniStat` — used in report mode.

- [ ] **Step 9: Run dart analyze**

- [ ] **Step 10: Commit**

```
feat(teacher): class detail management mode with select + bulk move

- ClassDetailScreen now supports management/report modes
- Management: no stats, tap for student info sheet (password visible)
- Select mode: checkbox multi-select + "Move to..." floating bar
- Report mode: stats bar, read-only student list
```

---

## Task 5: Router + Report Mode Integration

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart`

- [ ] **Step 1: Update router to pass mode**

In `router.dart`, the `ClassDetailScreen` route (around line 488):
```dart
GoRoute(
  parentNavigatorKey: rootNavigatorKey,
  path: AppRoutes.teacherClassDetail,
  builder: (context, state) {
    final classId = state.pathParameters['classId']!;
    final mode = state.extra as ClassDetailMode? ?? ClassDetailMode.management;
    return ClassDetailScreen(classId: classId, mode: mode);
  },
),
```

- [ ] **Step 2: Update class_overview_report_screen navigation**

In `class_overview_report_screen.dart`, change the `onTap` navigation to pass report mode:
```dart
onTap: () => context.push(
  AppRoutes.teacherClassDetailPath(classItem.id),
  extra: ClassDetailMode.report,
),
```

Add import: `import '../../screens/teacher/class_detail_screen.dart';` (for the enum)

- [ ] **Step 3: Run dart analyze**

- [ ] **Step 4: Commit**

```
feat(teacher): route class detail with management/report mode

Classes tab → management mode (default)
Reports → Class Overview → report mode (via state.extra)
```

---

## Pre-flight Checklist

- [ ] On `main` branch
- [ ] `dart analyze lib/` has 0 errors
- [ ] `supabase db push --dry-run` clean
