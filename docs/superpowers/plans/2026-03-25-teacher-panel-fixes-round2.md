# Teacher Panel Fixes Round 2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix remaining bugs (broken RLS, security gaps, logic errors) and clean up code quality issues (duplicates, debugPrint, inconsistencies) in the teacher panel.

**Architecture:** 6 independent tasks. Tasks 1-2 are security/DB fixes (SQL migrations + minimal Flutter). Tasks 3-4 are bug fixes (Flutter only). Tasks 5-6 are code quality cleanup (Flutter only). Each task produces a standalone commit.

**Tech Stack:** PostgreSQL (Supabase migrations), Flutter/Dart, Riverpod

---

## Task 1: Fix `updateStudentClass` — Broken RLS + Cross-School RPC Security

**Problem:** Three issues:
1. `updateStudentClass` does a direct UPDATE on `profiles` table, but RLS only allows `id = auth.uid()`. Teachers can't change student's class — **feature is broken in production**.
2. `get_student_progress_with_books` has no school-scope check — any teacher can view any student's progress.
3. `get_assignments_with_stats` authorization is too loose — any teacher can view another teacher's assignments.

**Fix:** Create RPCs for all three. The `updateStudentClass` needs a new `SECURITY DEFINER` RPC. The other two need school-scope guards added.

**Files:**
- Create: `supabase/migrations/20260325000012_fix_teacher_rpc_security.sql`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart` (add constant)
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart` (use RPC for updateStudentClass)

- [ ] **Step 1: Write the migration**

```sql
-- =============================================
-- FIX: updateStudentClass broken (RLS blocks teacher UPDATE on profiles)
-- FIX: get_student_progress_with_books missing school-scope check
-- FIX: get_assignments_with_stats missing school-scope check
-- =============================================

-- 1. New RPC for changing student's class (teacher action)
CREATE OR REPLACE FUNCTION update_student_class(
  p_student_id UUID,
  p_new_class_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_caller_school_id UUID;
  v_student_school_id UUID;
  v_class_school_id UUID;
BEGIN
  -- Must be teacher or higher
  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  -- Get caller's school
  SELECT school_id INTO v_caller_school_id
  FROM profiles WHERE id = auth.uid();

  -- Verify student is in same school
  SELECT school_id INTO v_student_school_id
  FROM profiles WHERE id = p_student_id AND role = 'student';

  IF v_student_school_id IS NULL THEN
    RAISE EXCEPTION 'Student not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_student_school_id THEN
    RAISE EXCEPTION 'Unauthorized: student is not in your school';
  END IF;

  -- Verify target class is in same school
  SELECT school_id INTO v_class_school_id
  FROM classes WHERE id = p_new_class_id;

  IF v_class_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found';
  END IF;

  IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
    RAISE EXCEPTION 'Unauthorized: class is not in your school';
  END IF;

  -- Update
  UPDATE profiles SET class_id = p_new_class_id WHERE id = p_student_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix get_student_progress_with_books: add school-scope for teachers
CREATE OR REPLACE FUNCTION get_student_progress_with_books(p_student_id UUID)
RETURNS TABLE (
  book_id UUID,
  book_title TEXT,
  book_cover_url TEXT,
  completion_percentage NUMERIC,
  total_reading_time INT,
  completed_chapters INT,
  total_chapters BIGINT,
  last_read_at TIMESTAMPTZ
) AS $$
DECLARE
  v_caller_school_id UUID;
  v_student_school_id UUID;
BEGIN
  -- Own data: always allowed
  IF auth.uid() = p_student_id THEN
    -- pass through
  ELSIF is_teacher_or_higher() THEN
    -- Teacher: must be same school
    SELECT school_id INTO v_caller_school_id FROM profiles WHERE id = auth.uid();
    SELECT school_id INTO v_student_school_id FROM profiles WHERE id = p_student_id;
    IF v_caller_school_id IS DISTINCT FROM v_student_school_id THEN
      RAISE EXCEPTION 'Unauthorized: student is not in your school';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    b.id as book_id,
    b.title::TEXT as book_title,
    b.cover_url::TEXT as book_cover_url,
    COALESCE(rp.completion_percentage, 0) as completion_percentage,
    COALESCE(rp.total_reading_time, 0) as total_reading_time,
    COALESCE(array_length(rp.completed_chapter_ids, 1), 0) as completed_chapters,
    (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = b.id) as total_chapters,
    rp.updated_at as last_read_at
  FROM reading_progress rp
  JOIN books b ON b.id = rp.book_id
  WHERE rp.user_id = p_student_id
  ORDER BY rp.updated_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Fix get_assignments_with_stats: enforce own assignments only
CREATE OR REPLACE FUNCTION get_assignments_with_stats(p_teacher_id UUID)
RETURNS TABLE (
  id UUID,
  teacher_id UUID,
  class_id UUID,
  class_name TEXT,
  type TEXT,
  title TEXT,
  description TEXT,
  content_config JSONB,
  start_date TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  total_students BIGINT,
  completed_students BIGINT
) AS $$
BEGIN
  -- Must be requesting own assignments (or admin)
  IF auth.uid() != p_teacher_id AND NOT (
    SELECT role = 'admin' FROM profiles WHERE id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Unauthorized: can only view own assignments';
  END IF;

  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher or higher role required';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.teacher_id,
    a.class_id,
    c.name::TEXT as class_name,
    a.type::TEXT,
    a.title::TEXT,
    a.description::TEXT,
    a.content_config,
    a.start_date,
    a.due_date,
    a.created_at,
    COUNT(asst.id) as total_students,
    COUNT(asst.id) FILTER (WHERE asst.status = 'completed') as completed_students
  FROM assignments a
  LEFT JOIN classes c ON c.id = a.class_id
  LEFT JOIN assignment_students asst ON asst.assignment_id = a.id
  WHERE a.teacher_id = p_teacher_id
  GROUP BY a.id, a.teacher_id, a.class_id, c.name, a.type, a.title,
           a.description, a.content_config, a.start_date, a.due_date, a.created_at
  ORDER BY a.due_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Add RPC constant**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, add in Teacher section:
```dart
static const updateStudentClass = 'update_student_class';
```

- [ ] **Step 3: Update repository to use RPC**

In `lib/data/repositories/supabase/supabase_teacher_repository.dart`, replace `updateStudentClass` method:
```dart
@override
Future<Either<Failure, void>> updateStudentClass({
  required String studentId,
  required String newClassId,
}) async {
  try {
    await _supabase.rpc(
      RpcFunctions.updateStudentClass,
      params: {
        'p_student_id': studentId,
        'p_new_class_id': newClassId,
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

- [ ] **Step 4: Run dart analyze**

Run: `dart analyze lib/data/repositories/supabase/supabase_teacher_repository.dart`

- [ ] **Step 5: Commit**

```
fix(security): RPC for updateStudentClass + school-scope on 2 RPCs

- updateStudentClass: new SECURITY DEFINER RPC (was broken by RLS)
- get_student_progress_with_books: add same-school check for teachers
- get_assignments_with_stats: enforce auth.uid() = p_teacher_id strictly
```

---

## Task 2: Fix Due Date Time Component Loss

**Problem:** When user picks a due date via `showDatePicker`, the returned `DateTime` is midnight (00:00:00). The assignment appears expired at the start of the due date instead of end-of-day.

**Files:**
- Modify: `lib/presentation/screens/teacher/create_assignment_screen.dart:94`

- [ ] **Step 1: Fix `_selectDate` due date branch**

In `create_assignment_screen.dart`, line 94, change:
```dart
// Before
_dueDate = picked;
// After
_dueDate = picked.copyWith(hour: 23, minute: 59, second: 59);
```

Also fix line 91 — when start date auto-advances due date:
```dart
// Before
_dueDate = _startDate.add(const Duration(days: 7));
// After
_dueDate = _startDate.add(const Duration(days: 7)).copyWith(hour: 23, minute: 59, second: 59);
```

- [ ] **Step 2: Run dart analyze**

Run: `dart analyze lib/presentation/screens/teacher/create_assignment_screen.dart`

- [ ] **Step 3: Commit**

```
fix(teacher): preserve 23:59:59 time on due date picker

showDatePicker returns midnight; without copyWith the assignment
appears expired at the start of the due day instead of end-of-day.
```

---

## Task 3: Fix Remaining DateTime.now() and Hardcoded String

**Problem:** Two spots missed in the previous round:
1. `getActiveAssignments` uses `DateTime.now()` instead of `AppClock.now()`
2. `getAssignmentDetail` has hardcoded `'completed'` string

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_student_assignment_repository.dart:78`
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart:300`

- [ ] **Step 1: Fix DateTime.now() in getActiveAssignments**

In `supabase_student_assignment_repository.dart:78`, change:
```dart
// Before
final now = DateTime.now();
// After
final now = AppClock.now();
```

Import should already exist from previous fixes.

- [ ] **Step 2: Fix hardcoded 'completed' in getAssignmentDetail**

In `supabase_teacher_repository.dart:300`, change:
```dart
// Before
.where((s) => s['status'] == 'completed')
// After
.where((s) => s['status'] == AssignmentStatus.completed.dbValue)
```

Add import if not present: `import 'package:owlio_shared/owlio_shared.dart';` (should already be there).

- [ ] **Step 3: Run dart analyze**

Run: `dart analyze lib/data/`

- [ ] **Step 4: Commit**

```
fix: use AppClock.now() in getActiveAssignments + enum dbValue in getAssignmentDetail
```

---

## Task 4: Fix Error Handling Inconsistency in Provider

**Problem:** `schoolBookReadingStatsProvider` throws on failure while every other teacher provider returns empty default. This makes the reading report the only screen that shows error state — all others silently show empty.

**Files:**
- Modify: `lib/presentation/providers/teacher_provider.dart:171`

- [ ] **Step 1: Fix schoolBookReadingStatsProvider error handling**

In `teacher_provider.dart`, change the `schoolBookReadingStatsProvider` failure handler:
```dart
// Before
(failure) => throw Exception(failure.message),
// After
(failure) {
  debugPrint('schoolBookReadingStatsProvider: error = ${failure.message}');
  return <BookReadingStats>[];
},
```

- [ ] **Step 2: Commit**

```
fix(teacher): consistent error handling in schoolBookReadingStatsProvider
```

---

## Task 5: Remove debugPrint Statements + Code Cleanup

**Problem:** Production `debugPrint` calls fire on every widget rebuild. Plus duplicate helpers that violate CLAUDE.md rules.

**Files:**
- Modify: `lib/presentation/screens/teacher/dashboard_screen.dart` (remove debugPrint, move `_formatTimeAgo` to ui_helpers)
- Modify: `lib/presentation/providers/teacher_provider.dart` (remove debugPrint statements)
- Modify: `lib/presentation/utils/ui_helpers.dart` (add `formatTimeAgo` to `TimeFormatter`)
- Modify: `lib/presentation/screens/teacher/student_detail_screen.dart` (replace `_formatReadingTime` with `TimeFormatter`)
- Modify: `lib/presentation/screens/teacher/classes_screen.dart` (replace `_getProgressColor` with `ScoreColors`)
- Modify: `lib/presentation/screens/teacher/reports/class_overview_report_screen.dart` (replace `_getProgressColor` with `ScoreColors`)

- [ ] **Step 1: Add `formatTimeAgo` to TimeFormatter in ui_helpers.dart**

In `lib/presentation/utils/ui_helpers.dart`, add to the `TimeFormatter` class:
```dart
static String formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays == 1) {
    return 'Yesterday';
  } else {
    return '${diff.inDays}d ago';
  }
}
```

- [ ] **Step 2: Update dashboard_screen.dart**

1. Remove `debugPrint` at line 149 (inside `_StatsGrid.build`)
2. Replace `_formatTimeAgo` method in `_RecentActivityList` with `TimeFormatter.formatTimeAgo`
3. Delete the private `_formatTimeAgo` method
4. Add import: `import '../../utils/ui_helpers.dart';` (if not present)

- [ ] **Step 3: Remove debugPrint from teacher_provider.dart**

Remove all `debugPrint` calls in:
- `teacherStatsProvider` (lines 24, 27, 41, 50)
- `currentTeacherClassesProvider` (lines 80, 82)

Keep the provider logic, just remove the debug logging.

- [ ] **Step 4: Replace _formatReadingTime in student_detail_screen.dart**

Replace usage of `_formatReadingTime(seconds)` with `TimeFormatter.formatReadingTime(seconds)`.
Delete the private `_formatReadingTime` method.
Import `ui_helpers.dart` if not already imported.

- [ ] **Step 5: Replace _getProgressColor in classes_screen.dart and class_overview_report_screen.dart**

In both files, replace `_getProgressColor(progress)` with `ScoreColors.getProgressColor(progress)`.
Delete the private `_getProgressColor` methods.
Import `ui_helpers.dart` if not already imported.

- [ ] **Step 6: Run dart analyze**

Run: `dart analyze lib/presentation/`

- [ ] **Step 7: Commit**

```
refactor(teacher): remove debugPrint + centralize duplicate helpers

- Remove production debugPrint from dashboard and teacher_provider
- _formatTimeAgo → TimeFormatter.formatTimeAgo (ui_helpers.dart)
- _formatReadingTime → TimeFormatter.formatReadingTime
- _getProgressColor → ScoreColors.getProgressColor (2 files)
```

---

## Task 6: Fix Leaderboard Refresh + RecentActivity Equatable Props

**Problem:** Two minor issues:
1. Leaderboard pull-to-refresh doesn't invalidate `classStudentsProvider` family — student data stays stale
2. `RecentActivity.props` missing name fields — Equatable won't detect name changes

**Files:**
- Modify: `lib/presentation/screens/teacher/reports/leaderboard_report_screen.dart`
- Modify: `lib/domain/entities/teacher.dart`

- [ ] **Step 1: Fix leaderboard refresh**

In `leaderboard_report_screen.dart`, find the `onRefresh` callback and add `classStudentsProvider` invalidation:
```dart
onRefresh: () async {
  ref.invalidate(allStudentsLeaderboardProvider);
  ref.invalidate(currentTeacherClassesProvider);
  // Invalidate all cached class student lists
  for (final classItem in ref.read(currentTeacherClassesProvider).valueOrNull ?? []) {
    ref.invalidate(classStudentsProvider(classItem.id));
  }
},
```

- [ ] **Step 2: Fix RecentActivity.props**

In `lib/domain/entities/teacher.dart`, update `RecentActivity.props`:
```dart
// Before
List<Object?> get props => [studentId, activityType, description, xpAmount, createdAt];
// After
List<Object?> get props => [studentId, studentFirstName, studentLastName, avatarUrl, activityType, description, xpAmount, createdAt];
```

- [ ] **Step 3: Run dart analyze**

Run: `dart analyze lib/`

- [ ] **Step 4: Commit**

```
fix(teacher): leaderboard refresh stale data + RecentActivity Equatable props
```

---

## Pre-flight Checklist

Before starting:
- [ ] On `main` branch
- [ ] `dart analyze lib/` has 0 errors
- [ ] `supabase db push --dry-run` clean
