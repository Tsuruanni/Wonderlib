# Student Class Change — Assignment Sync

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a student joins or leaves a class, automatically sync their assignment enrollments so new students get existing active assignments and transferred students are withdrawn from old-class assignments.

**Architecture:** A PostgreSQL `AFTER UPDATE OF class_id` trigger on `profiles` handles all the logic server-side. When `class_id` changes: (1) withdraw from old class's non-completed assignments, (2) enroll in new class's active/non-expired assignments, (3) backfill unit assignment progress from existing learning path work. Flutter changes are minimal — add `withdrawn` status to the enum and filter it from student views.

**Tech Stack:** PostgreSQL trigger + PL/pgSQL functions, Dart (owlio_shared enum), Flutter (minimal UI adjustments)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `supabase/migrations/20260327000009_student_class_change_sync.sql` | DB trigger, helper function, stats RPC updates |
| Modify | `packages/owlio_shared/lib/src/enums/assignment_status.dart` | Add `withdrawn` enum value |
| Modify | `lib/presentation/utils/ui_helpers.dart` | Add withdrawn color/icon to `AssignmentColors` and `StudentAssignmentColors` |
| Modify | `lib/domain/entities/student_assignment.dart` | Add withdrawn to `StudentAssignmentStatusDisplay` extension |
| Modify | `lib/data/repositories/supabase/supabase_student_assignment_repository.dart` | Filter withdrawn from student queries |

---

### Task 1: Database Migration — Trigger and RPC Updates

**Files:**
- Create: `supabase/migrations/20260327000009_student_class_change_sync.sql`

This single migration handles everything: CHECK constraint expansion, helper function, trigger function, trigger, and stats RPC updates.

- [ ] **Step 1: Create the migration file**

```sql
-- =============================================
-- Student Class Change → Assignment Sync
--
-- When a student's class_id changes on profiles:
-- 1. Withdraw (soft-delete) from old class's non-completed assignments
-- 2. Enroll in new class's active, non-expired assignments
-- 3. Backfill unit assignment progress from existing LP work
--
-- Also updates stats RPCs to exclude 'withdrawn' from counts,
-- and sync RPC to skip withdrawn students.
-- =============================================

-- 1. Expand assignment_students status CHECK to include 'withdrawn'
ALTER TABLE assignment_students
  DROP CONSTRAINT IF EXISTS assignment_students_status_check;

ALTER TABLE assignment_students
  ADD CONSTRAINT assignment_students_status_check
  CHECK (status IN ('pending', 'in_progress', 'completed', 'overdue', 'withdrawn'));

-- 2. Internal helper: backfill a single student's unit assignment progress
--    Mirrors the per-student logic from sync_unit_assignment_progress,
--    but without auth checks (called from trigger context).
CREATE OR REPLACE FUNCTION _backfill_student_unit_progress(
  p_assignment_id UUID,
  p_student_id UUID
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_unit_id UUID;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  -- Get the scope LP unit ID from the assignment's content_config
  SELECT (a.content_config->>'scopeLpUnitId')::UUID INTO v_scope_lp_unit_id
  FROM assignments a
  WHERE a.id = p_assignment_id AND a.type = 'unit';

  IF v_scope_lp_unit_id IS NULL THEN RETURN; END IF;

  -- Count total trackable items (word_list + book only; game/treasure are not graded)
  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN RETURN; END IF;

  -- Count completed items for this student
  SELECT COUNT(*) INTO v_completed
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book')
    AND (
      (sui.item_type = 'word_list' AND EXISTS (
        SELECT 1 FROM user_word_list_progress uwlp
        WHERE uwlp.user_id = p_student_id
          AND uwlp.word_list_id = sui.word_list_id
          AND uwlp.completed_at IS NOT NULL
      ))
      OR
      (sui.item_type = 'book' AND COALESCE(
        (SELECT array_length(rp.completed_chapter_ids, 1)
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id),
        0
      ) >= (SELECT COUNT(*)::INT FROM chapters ch WHERE ch.book_id = sui.book_id))
    );

  IF v_completed = 0 THEN RETURN; END IF;

  v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

  -- Update the assignment_students row with backfilled progress
  IF v_progress >= 100 THEN
    UPDATE assignment_students
    SET status = 'completed', progress = 100, completed_at = NOW(), started_at = COALESCE(started_at, NOW())
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id
      AND status != 'completed';
  ELSE
    UPDATE assignment_students
    SET progress = v_progress,
        status = 'in_progress',
        started_at = COALESCE(started_at, NOW())
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id;
  END IF;
END;
$$;

-- 3. Main trigger function
CREATE OR REPLACE FUNCTION handle_student_class_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_assignment RECORD;
BEGIN
  -- Only process students
  IF NEW.role != 'student' THEN RETURN NEW; END IF;

  -- Only fire when class_id actually changes
  IF OLD.class_id IS NOT DISTINCT FROM NEW.class_id THEN RETURN NEW; END IF;

  -- STEP 1: Withdraw from old class's non-completed assignments
  --         Completed assignments are left untouched (student earned them).
  IF OLD.class_id IS NOT NULL THEN
    UPDATE assignment_students AS asn
    SET status = 'withdrawn'
    WHERE asn.student_id = NEW.id
      AND asn.status IN ('pending', 'in_progress')
      AND asn.assignment_id IN (
        SELECT a.id FROM assignments a WHERE a.class_id = OLD.class_id
      );
  END IF;

  -- STEP 2: Enroll in new class's active, non-expired assignments
  IF NEW.class_id IS NOT NULL THEN
    INSERT INTO assignment_students (assignment_id, student_id, status, progress)
    SELECT a.id, NEW.id, 'pending', 0
    FROM assignments a
    WHERE a.class_id = NEW.class_id
      AND a.due_date > NOW()
    ON CONFLICT (assignment_id, student_id) DO UPDATE
    SET status = 'pending',
        progress = 0,
        score = NULL,
        started_at = NULL,
        completed_at = NULL
    WHERE assignment_students.status = 'withdrawn';

    -- STEP 3: Backfill progress for unit-type assignments
    --         If the student already completed items on the learning path,
    --         reflect that in the assignment progress.
    FOR v_assignment IN
      SELECT a.id
      FROM assignments a
      WHERE a.class_id = NEW.class_id
        AND a.due_date > NOW()
        AND a.type = 'unit'
    LOOP
      PERFORM _backfill_student_unit_progress(v_assignment.id, NEW.id);
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Create trigger (fires only when class_id column is in the UPDATE SET clause)
DROP TRIGGER IF EXISTS on_student_class_change ON profiles;
CREATE TRIGGER on_student_class_change
  AFTER UPDATE OF class_id ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION handle_student_class_change();

-- 5. Update get_assignments_with_stats: exclude withdrawn from counts
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
  IF auth.uid() != p_teacher_id AND NOT (
    SELECT pr.role = 'admin' FROM profiles pr WHERE pr.id = auth.uid()
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
    COUNT(asst.id) FILTER (WHERE asst.status != 'withdrawn') as total_students,
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

-- 6. Update get_assignment_detail_with_stats: exclude withdrawn from counts
DROP FUNCTION IF EXISTS get_assignment_detail_with_stats(UUID);

CREATE FUNCTION get_assignment_detail_with_stats(p_assignment_id UUID)
RETURNS TABLE (
  id UUID,
  teacher_id UUID,
  class_id UUID,
  class_name VARCHAR,
  type VARCHAR,
  title VARCHAR,
  description TEXT,
  content_config JSONB,
  start_date TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  total_students BIGINT,
  completed_students BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_teacher_id UUID;
BEGIN
  SELECT a.teacher_id INTO v_teacher_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found: %', p_assignment_id;
  END IF;

  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.teacher_id,
    a.class_id,
    c.name::VARCHAR AS class_name,
    a.type::VARCHAR,
    a.title::VARCHAR,
    a.description,
    a.content_config,
    a.start_date,
    a.due_date,
    a.created_at,
    COUNT(asn.id) FILTER (WHERE asn.status != 'withdrawn') AS total_students,
    COUNT(asn.id) FILTER (WHERE asn.status = 'completed') AS completed_students
  FROM assignments a
  LEFT JOIN classes c ON c.id = a.class_id
  LEFT JOIN assignment_students asn ON asn.assignment_id = a.id
  WHERE a.id = p_assignment_id
  GROUP BY a.id, a.teacher_id, a.class_id, c.name, a.type, a.title,
           a.description, a.content_config, a.start_date, a.due_date, a.created_at;
END;
$$;

-- 7. Update sync_unit_assignment_progress: skip withdrawn students
CREATE OR REPLACE FUNCTION sync_unit_assignment_progress(p_assignment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
#variable_conflict use_column
DECLARE
  v_teacher_id UUID;
  v_scope_lp_unit_id UUID;
  v_student RECORD;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  SELECT a.teacher_id, (a.content_config->>'scopeLpUnitId')::UUID
  INTO v_teacher_id, v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;
  IF v_scope_lp_unit_id IS NULL THEN
    RAISE EXCEPTION 'Not a unit assignment';
  END IF;

  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles pr WHERE pr.id = auth.uid() AND pr.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN RETURN; END IF;

  FOR v_student IN
    SELECT asn.student_id FROM assignment_students asn
    WHERE asn.assignment_id = p_assignment_id
      AND asn.status NOT IN ('completed', 'withdrawn')
  LOOP
    SELECT COUNT(*) INTO v_completed
    FROM scope_unit_items sui
    WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
      AND sui.item_type IN ('word_list', 'book')
      AND (
        (sui.item_type = 'word_list' AND EXISTS (
          SELECT 1 FROM user_word_list_progress uwlp
          WHERE uwlp.user_id = v_student.student_id
            AND uwlp.word_list_id = sui.word_list_id
            AND uwlp.completed_at IS NOT NULL
        ))
        OR
        (sui.item_type = 'book' AND COALESCE(
          (SELECT array_length(rp.completed_chapter_ids, 1)
           FROM reading_progress rp
           WHERE rp.user_id = v_student.student_id AND rp.book_id = sui.book_id),
          0
        ) >= (SELECT COUNT(*)::INT FROM chapters ch WHERE ch.book_id = sui.book_id))
      );

    v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

    IF v_progress >= 100 THEN
      UPDATE assignment_students
      SET status = 'completed', progress = 100, score = NULL, completed_at = NOW()
      WHERE assignment_id = p_assignment_id AND student_id = v_student.student_id
        AND status != 'completed';
    ELSIF v_completed > 0 THEN
      UPDATE assignment_students
      SET progress = v_progress,
          status = CASE WHEN status = 'pending' THEN 'in_progress' ELSE status END,
          started_at = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END
      WHERE assignment_id = p_assignment_id AND student_id = v_student.student_id;
    END IF;
  END LOOP;
END;
$$;
```

- [ ] **Step 2: Preview migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied, no errors.

- [ ] **Step 3: Apply migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Verify trigger exists**

Run this in Supabase SQL Editor:
```sql
SELECT tgname, tgtype, tgenabled
FROM pg_trigger
WHERE tgname = 'on_student_class_change';
```
Expected: One row with the trigger name.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260327000009_student_class_change_sync.sql
git commit -m "feat: add trigger to sync assignments on student class change

When profiles.class_id changes for a student:
- Withdraw (soft-delete) from old class's non-completed assignments
- Enroll in new class's active, non-expired assignments
- Backfill unit assignment progress from existing LP work
- Stats RPCs updated to exclude withdrawn from counts"
```

---

### Task 2: Shared Package — Add `withdrawn` Enum Value

**Files:**
- Modify: `packages/owlio_shared/lib/src/enums/assignment_status.dart`

- [ ] **Step 1: Add withdrawn to AssignmentStatus enum**

Add `withdrawn('withdrawn')` to the enum and update `displayName`:

```dart
/// Status of a student's assignment progress.
enum AssignmentStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  overdue('overdue'),
  withdrawn('withdrawn');

  final String dbValue;

  const AssignmentStatus(this.dbValue);

  /// Parse from database string (snake_case).
  static AssignmentStatus fromDbValue(String value) {
    return AssignmentStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => AssignmentStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.overdue:
        return 'Overdue';
      case AssignmentStatus.withdrawn:
        return 'Withdrawn';
    }
  }
}
```

- [ ] **Step 2: Run analyze on shared package**

Run: `cd packages/owlio_shared && dart analyze lib/`
Expected: No errors. May show warnings about non-exhaustive switches in dependent packages (that's expected — we fix those next).

- [ ] **Step 3: Commit**

```bash
git add packages/owlio_shared/lib/src/enums/assignment_status.dart
git commit -m "feat(shared): add withdrawn status to AssignmentStatus enum"
```

---

### Task 3: Flutter — UI Helpers for Withdrawn Status

**Files:**
- Modify: `lib/presentation/utils/ui_helpers.dart`

Both `AssignmentColors` (teacher-side) and `StudentAssignmentColors` (student-side) have switch statements on `AssignmentStatus` that will break after adding `withdrawn`. Add the new case to all four methods.

- [ ] **Step 1: Add withdrawn to AssignmentColors**

In `AssignmentColors.getStatusColor` (around line 35), add after the `overdue` case:

```dart
  static Color getStatusColor(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.pending:
        return Colors.grey;
      case AssignmentStatus.inProgress:
        return Colors.blue;
      case AssignmentStatus.completed:
        return Colors.green;
      case AssignmentStatus.overdue:
        return Colors.red;
      case AssignmentStatus.withdrawn:
        return Colors.grey.shade400;
    }
  }
```

In `AssignmentColors.getStatusIcon` (around line 48), add after the `overdue` case:

```dart
  static IconData getStatusIcon(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.pending:
        return Icons.schedule;
      case AssignmentStatus.inProgress:
        return Icons.play_circle;
      case AssignmentStatus.completed:
        return Icons.check_circle;
      case AssignmentStatus.overdue:
        return Icons.warning;
      case AssignmentStatus.withdrawn:
        return Icons.person_remove;
    }
  }
```

- [ ] **Step 2: Add withdrawn to StudentAssignmentColors**

In `StudentAssignmentColors.getStatusColor` (around line 86), add after the `overdue` case:

```dart
  static Color getStatusColor(StudentAssignmentStatus status) {
    switch (status) {
      case StudentAssignmentStatus.pending:
        return Colors.grey;
      case StudentAssignmentStatus.inProgress:
        return Colors.blue;
      case StudentAssignmentStatus.completed:
        return Colors.green;
      case StudentAssignmentStatus.overdue:
        return Colors.red;
      case StudentAssignmentStatus.withdrawn:
        return Colors.grey.shade400;
    }
  }
```

In `StudentAssignmentColors.getStatusIcon` (around line 99), add after the `overdue` case:

```dart
  static IconData getStatusIcon(StudentAssignmentStatus status) {
    switch (status) {
      case StudentAssignmentStatus.pending:
        return Icons.schedule;
      case StudentAssignmentStatus.inProgress:
        return Icons.play_circle;
      case StudentAssignmentStatus.completed:
        return Icons.check_circle;
      case StudentAssignmentStatus.overdue:
        return Icons.warning;
      case StudentAssignmentStatus.withdrawn:
        return Icons.person_remove;
    }
  }
```

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/presentation/utils/ui_helpers.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/utils/ui_helpers.dart
git commit -m "feat: add withdrawn status color and icon to UI helpers"
```

---

### Task 4: Flutter — Student Assignment Entity Display Extension

**Files:**
- Modify: `lib/domain/entities/student_assignment.dart`

The `StudentAssignmentStatusDisplay` extension has a switch on `AssignmentStatus` that needs the new case.

- [ ] **Step 1: Add withdrawn to StudentAssignmentStatusDisplay**

In the `studentDisplayName` getter (around line 13), add the withdrawn case:

```dart
extension StudentAssignmentStatusDisplay on AssignmentStatus {
  String get studentDisplayName {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.overdue:
        return 'Overdue';
      case AssignmentStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  /// Backwards compat: fromString maps to fromDbValue.
  static AssignmentStatus fromString(String value) =>
      AssignmentStatus.fromDbValue(value);
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/domain/entities/student_assignment.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/student_assignment.dart
git commit -m "feat: add withdrawn to student assignment display extension"
```

---

### Task 5: Flutter — Filter Withdrawn from Student Queries

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_student_assignment_repository.dart`

The `getStudentAssignments` method fetches ALL statuses. After adding `withdrawn`, these rows should never reach the student client. Add a `.neq('status', 'withdrawn')` filter to the query.

- [ ] **Step 1: Add filter to getStudentAssignments**

In `getStudentAssignments` (around line 26), add the filter after `.eq('student_id', studentId)`:

```dart
  @override
  Future<Either<Failure, List<StudentAssignment>>> getStudentAssignments(
    String studentId,
  ) async {
    debugPrint('🔍 getStudentAssignments called with studentId: $studentId');
    try {
      final response = await _supabase
          .from(DbTables.assignmentStudents)
          .select('''
            *,
            assignments:assignment_id (
              id,
              title,
              description,
              type,
              content_config,
              start_date,
              due_date,
              teacher_id,
              class_id,
              profiles:teacher_id (first_name, last_name),
              classes:class_id (name)
            )
          ''')
          .eq('student_id', studentId)
          .neq('status', 'withdrawn')
          .order('created_at', ascending: false);
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/data/repositories/supabase/supabase_student_assignment_repository.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/supabase/supabase_student_assignment_repository.dart
git commit -m "feat: filter withdrawn assignments from student queries"
```

---

### Task 6: Full Verification

- [ ] **Step 1: Run full dart analyze**

Run: `dart analyze lib/`
Expected: No errors related to assignment status. All switch statements should be exhaustive.

- [ ] **Step 2: Check for any remaining non-exhaustive switches**

Run: `grep -rn "case AssignmentStatus\." lib/ | grep -v withdrawn | grep -v "//"`

If any switch statement on `AssignmentStatus` is missing the `withdrawn` case, it will show up as a compile warning in step 1. Fix any that appear.

- [ ] **Step 3: Run flutter test**

Run: `flutter test`
Expected: All existing tests pass. No test changes needed since this is additive.

- [ ] **Step 4: Manual smoke test (SQL Editor)**

Run in Supabase SQL Editor to verify the trigger works:

```sql
-- Test: move a student to a new class and verify assignment_students rows are created
-- (Use test data — pick a student and class with active assignments)

-- Check before:
SELECT asn.id, a.title, asn.status, asn.progress
FROM assignment_students asn
JOIN assignments a ON a.id = asn.assignment_id
WHERE asn.student_id = '<test_student_id>';

-- Move student:
UPDATE profiles SET class_id = '<new_class_id>' WHERE id = '<test_student_id>';

-- Check after — should see new rows for new class assignments, old ones withdrawn:
SELECT asn.id, a.title, asn.status, asn.progress, a.class_id
FROM assignment_students asn
JOIN assignments a ON a.id = asn.assignment_id
WHERE asn.student_id = '<test_student_id>';
```

- [ ] **Step 5: Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "fix: address any verification issues from class change sync"
```
