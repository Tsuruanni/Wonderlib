# Learning Paths Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 17 audit findings from Feature #7 (Learning Paths) — security, architecture, dead code, database housekeeping.

**Architecture:** Single SQL migration for all DB changes (auth checks, RLS fixes, FK cascade, indexes, sort_order lock). Single Dart commit for code changes (enum refactor, dead code removal, debugPrint cleanup).

**Tech Stack:** PostgreSQL (Supabase migrations), Dart/Flutter, Riverpod

**Spec:** `docs/superpowers/specs/2026-03-27-learning-paths-audit-fixes-design.md`

---

### Task 1: SQL Migration — Security & Database Housekeeping

**Files:**
- Create: `supabase/migrations/20260327000010_learning_path_audit_fixes.sql`

- [ ] **Step 1: Create migration file with all security and DB fixes**

Create `supabase/migrations/20260327000010_learning_path_audit_fixes.sql`:

```sql
-- ============================================
-- Learning Paths Audit Fixes
-- Findings: #1,#2,#3,#4,#5,#16,#17,#18,#20
-- ============================================

-- #5: Fix template RLS role mismatch (head_teacher → head)
-- learning_path_templates
DROP POLICY IF EXISTS "admin_full_access" ON learning_path_templates;
CREATE POLICY "admin_full_access" ON learning_path_templates
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

-- learning_path_template_units
DROP POLICY IF EXISTS "admin_full_access" ON learning_path_template_units;
CREATE POLICY "admin_full_access" ON learning_path_template_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

-- learning_path_template_items
DROP POLICY IF EXISTS "admin_full_access" ON learning_path_template_items;
CREATE POLICY "admin_full_access" ON learning_path_template_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

-- #4: path_daily_review_completions — block DELETE (prevent DR replay)
DROP POLICY IF EXISTS "users_own_data" ON path_daily_review_completions;

CREATE POLICY "users_select_own" ON path_daily_review_completions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own" ON path_daily_review_completions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own" ON path_daily_review_completions
  FOR UPDATE USING (auth.uid() = user_id);

-- #16: scope_learning_paths.class_id — add ON DELETE CASCADE
ALTER TABLE scope_learning_paths
  DROP CONSTRAINT scope_learning_paths_class_id_fkey,
  ADD CONSTRAINT scope_learning_paths_class_id_fkey
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE;

-- #17: Add missing index on scope_learning_paths.template_id
CREATE INDEX IF NOT EXISTS idx_scope_lp_template ON scope_learning_paths(template_id);

-- #18: Drop redundant indexes (covered by UNIQUE constraint)
DROP INDEX IF EXISTS idx_path_dr_user;
DROP INDEX IF EXISTS idx_path_dr_unit;

-- #1 + #20: Recreate apply_learning_path_template with auth check + atomic sort_order
DROP FUNCTION IF EXISTS apply_learning_path_template(UUID, UUID, INTEGER, UUID, UUID);

CREATE OR REPLACE FUNCTION apply_learning_path_template(
  p_template_id UUID,
  p_school_id   UUID,
  p_grade       INTEGER DEFAULT NULL,
  p_class_id    UUID DEFAULT NULL,
  p_user_id     UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_id UUID;
  v_template RECORD;
  v_template_unit RECORD;
  v_scope_unit_id UUID;
  v_item RECORD;
  v_sort_order INTEGER;
BEGIN
  -- Auth check: admin, head, or teacher only
  IF NOT EXISTS(
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('admin', 'head', 'teacher')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT name, sequential_lock, books_exempt_from_lock
  INTO v_template
  FROM learning_path_templates
  WHERE id = p_template_id;

  IF v_template.name IS NULL THEN
    RAISE EXCEPTION 'Template not found: %', p_template_id;
  END IF;

  -- Atomic sort_order with row lock
  SELECT COALESCE(MAX(sort_order) + 1, 0)
  INTO v_sort_order
  FROM scope_learning_paths
  WHERE school_id = p_school_id
    AND grade IS NOT DISTINCT FROM p_grade
    AND class_id IS NOT DISTINCT FROM p_class_id
  FOR UPDATE;

  INSERT INTO scope_learning_paths (
    name, template_id, school_id, grade, class_id, sort_order, created_by,
    sequential_lock, books_exempt_from_lock
  )
  VALUES (
    v_template.name,
    p_template_id,
    p_school_id,
    p_grade,
    p_class_id,
    v_sort_order,
    p_user_id,
    v_template.sequential_lock,
    v_template.books_exempt_from_lock
  )
  RETURNING id INTO v_scope_lp_id;

  FOR v_template_unit IN
    SELECT id, unit_id, sort_order
    FROM learning_path_template_units
    WHERE template_id = p_template_id
    ORDER BY sort_order
  LOOP
    INSERT INTO scope_learning_path_units (scope_learning_path_id, unit_id, sort_order)
    VALUES (v_scope_lp_id, v_template_unit.unit_id, v_template_unit.sort_order)
    RETURNING id INTO v_scope_unit_id;

    FOR v_item IN
      SELECT item_type, word_list_id, book_id, sort_order
      FROM learning_path_template_items
      WHERE template_unit_id = v_template_unit.id
      ORDER BY sort_order
    LOOP
      INSERT INTO scope_unit_items (scope_lp_unit_id, item_type, word_list_id, book_id, sort_order)
      VALUES (v_scope_unit_id, v_item.item_type, v_item.word_list_id, v_item.book_id, v_item.sort_order);
    END LOOP;
  END LOOP;

  RETURN v_scope_lp_id;
END;
$$;

-- #2: Recreate get_user_learning_paths with auth check
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID);

CREATE OR REPLACE FUNCTION get_user_learning_paths(p_user_id UUID)
RETURNS TABLE (
  learning_path_id        UUID,
  learning_path_name      VARCHAR,
  lp_sort_order           INTEGER,
  sequential_lock         BOOLEAN,
  books_exempt_from_lock  BOOLEAN,
  unit_id                 UUID,
  unit_name               VARCHAR,
  unit_color              VARCHAR,
  unit_icon               VARCHAR,
  unit_sort_order         INTEGER,
  item_type               VARCHAR,
  item_id                 UUID,
  item_sort_order         INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
  v_class_id UUID;
BEGIN
  -- Auth check: user can only fetch own paths
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT p.school_id, c.grade, p.class_id
  INTO v_school_id, v_grade, v_class_id
  FROM profiles p
  LEFT JOIN classes c ON c.id = p.class_id
  WHERE p.id = p_user_id;

  IF v_school_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    slp.id AS learning_path_id,
    slp.name::VARCHAR AS learning_path_name,
    slp.sort_order AS lp_sort_order,
    slp.sequential_lock,
    slp.books_exempt_from_lock,
    vu.id AS unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR AS item_type,
    COALESCE(sui.word_list_id, sui.book_id) AS item_id,
    sui.sort_order AS item_sort_order
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = v_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;

-- #3: Recreate get_path_daily_reviews with auth check (convert SQL → plpgsql)
DROP FUNCTION IF EXISTS get_path_daily_reviews(UUID);

CREATE OR REPLACE FUNCTION get_path_daily_reviews(p_user_id UUID)
RETURNS TABLE (
  scope_lp_unit_id UUID,
  "position"       INTEGER,
  completed_at     DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Auth check: user can only fetch own DR history
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT pdr.scope_lp_unit_id, pdr."position", pdr.completed_at
  FROM path_daily_review_completions pdr
  WHERE pdr.user_id = p_user_id
  ORDER BY pdr.completed_at DESC;
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Migration applies cleanly with no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260327000010_learning_path_audit_fixes.sql
git commit -m "security: add auth checks to LP RPCs, fix RLS policies, DB housekeeping (#1-5,#16-18,#20)"
```

---

### Task 2: Entity Enum Refactor (#8)

**Files:**
- Modify: `lib/domain/entities/class_learning_path_unit.dart`
- Modify: `lib/domain/entities/unit_assignment_item.dart`
- Modify: `lib/domain/entities/student_unit_progress_item.dart`
- Modify: `lib/data/models/assignment/class_learning_path_unit_model.dart`
- Modify: `lib/data/models/assignment/unit_assignment_item_model.dart`
- Modify: `lib/data/models/assignment/student_unit_progress_item_model.dart`

- [ ] **Step 1: Update `ClassLearningPathItem` entity to use enum**

In `lib/domain/entities/class_learning_path_unit.dart`:

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Change `ClassLearningPathItem.itemType` from `String` to `LearningPathItemType`:
```dart
  final LearningPathItemType itemType;
```

Update `trackableItemCount` in `ClassLearningPathUnit`:
```dart
  int get trackableItemCount =>
      items.where((i) => i.itemType == LearningPathItemType.wordList || i.itemType == LearningPathItemType.book).length;
```

- [ ] **Step 2: Update `UnitAssignmentItem` entity to use enum**

In `lib/domain/entities/unit_assignment_item.dart`:

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Change `itemType` from `String` to `LearningPathItemType`:
```dart
  final LearningPathItemType itemType;
```

Update `isTracked` and `isCompleted`:
```dart
  bool get isTracked => itemType == LearningPathItemType.wordList || itemType == LearningPathItemType.book;

  bool get isCompleted {
    if (itemType == LearningPathItemType.wordList) return isWordListCompleted ?? false;
    if (itemType == LearningPathItemType.book) return isBookCompleted ?? false;
    return false;
  }
```

- [ ] **Step 3: Update `StudentUnitProgressItem` entity to use enum**

In `lib/domain/entities/student_unit_progress_item.dart`:

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Change `itemType` from `String` to `LearningPathItemType`:
```dart
  final LearningPathItemType itemType;
```

Update `isTracked` and `isCompleted`:
```dart
  bool get isTracked => itemType == LearningPathItemType.wordList || itemType == LearningPathItemType.book;

  bool get isCompleted {
    if (itemType == LearningPathItemType.wordList) return isWordListCompleted ?? false;
    if (itemType == LearningPathItemType.book) return isBookCompleted ?? false;
    return false;
  }
```

- [ ] **Step 4: Update `ClassLearningPathUnitModel` to parse enum**

In `lib/data/models/assignment/class_learning_path_unit_model.dart`:

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Change item construction in `fromRpcRows` (the `unitBuilders[scopeLpUnitId]!.items.add(...)` block):
```dart
        unitBuilders[scopeLpUnitId]!.items.add(ClassLearningPathItem(
          itemType: LearningPathItemType.fromDbValue(row['item_type'] as String),
          sortOrder: (row['item_sort_order'] as num).toInt(),
          wordListId: row['word_list_id'] as String?,
          wordListName: row['word_list_name'] as String?,
          words: words,
          bookId: row['book_id'] as String?,
          bookTitle: row['book_title'] as String?,
          bookChapterCount: (row['book_chapter_count'] as num?)?.toInt(),
        ));
```

- [ ] **Step 5: Update `UnitAssignmentItemModel` to parse enum**

In `lib/data/models/assignment/unit_assignment_item_model.dart`:

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Change `fromJson`:
```dart
  static UnitAssignmentItem fromJson(Map<String, dynamic> json) {
    return UnitAssignmentItem(
      itemType: LearningPathItemType.fromDbValue(json['item_type'] as String),
      sortOrder: (json['sort_order'] as num).toInt(),
      wordListId: json['word_list_id'] as String?,
      wordListName: json['word_list_name'] as String?,
      wordCount: (json['word_count'] as num?)?.toInt(),
      isWordListCompleted: json['is_word_list_completed'] as bool?,
      bookId: json['book_id'] as String?,
      bookTitle: json['book_title'] as String?,
      totalChapters: (json['total_chapters'] as num?)?.toInt(),
      completedChapters: (json['completed_chapters'] as num?)?.toInt(),
      isBookCompleted: json['is_book_completed'] as bool?,
    );
  }
```

- [ ] **Step 6: Update `StudentUnitProgressItemModel` to parse enum**

In `lib/data/models/assignment/student_unit_progress_item_model.dart`:

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Change `fromJson`:
```dart
  static StudentUnitProgressItem fromJson(Map<String, dynamic> json) {
    return StudentUnitProgressItem(
      itemType: LearningPathItemType.fromDbValue(json['out_item_type'] as String),
      sortOrder: (json['out_sort_order'] as num).toInt(),
      wordListId: json['out_word_list_id'] as String?,
      wordListName: json['out_word_list_name'] as String?,
      wordCount: (json['out_word_count'] as num?)?.toInt(),
      isWordListCompleted: json['out_is_word_list_completed'] as bool?,
      bestScore: (json['out_best_score'] as num?)?.toDouble(),
      bestAccuracy: (json['out_best_accuracy'] as num?)?.toDouble(),
      totalSessions: (json['out_total_sessions'] as num?)?.toInt(),
      bookId: json['out_book_id'] as String?,
      bookTitle: json['out_book_title'] as String?,
      totalChapters: (json['out_total_chapters'] as num?)?.toInt(),
      completedChapters: (json['out_completed_chapters'] as num?)?.toInt(),
      isBookCompleted: json['out_is_book_completed'] as bool?,
    );
  }
```

- [ ] **Step 7: Run dart analyze**

Run: `dart analyze lib/`
Expected: No issues found.

---

### Task 3: Dead Code Removal (#9–13)

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart:50` (#9)
- Modify: `lib/presentation/widgets/vocabulary/path_node.dart:16,405-430,421,577` (#10, #12)
- Modify: `lib/app/router.dart:100-101,323-329` (#11)
- Modify: `owlio_admin/lib/features/learning_path_assignments/screens/assignment_list_screen.dart:12-30` (#13)

- [ ] **Step 1: Remove `RpcFunctions.getPathDailyReviews` (#9)**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, delete line 50:
```dart
  static const getPathDailyReviews = 'get_path_daily_reviews';
```

- [ ] **Step 2: Remove `LabelPosition.below` and its build branch (#10)**

In `lib/presentation/widgets/vocabulary/path_node.dart`:

Change enum at line 16 from:
```dart
enum LabelPosition { below, left, right }
```
to:
```dart
enum LabelPosition { left, right }
```

Delete the entire `if (widget.labelPosition == LabelPosition.below)` block (lines 405–430). This is the block that starts with `if (widget.labelPosition == LabelPosition.below) {` and ends with its closing `}` and semicolon before the next layout branch.

- [ ] **Step 3: Remove stale comments (#12)**

In `lib/presentation/widgets/vocabulary/path_node.dart`:

Delete the comment at line 416 (inside the below block — if already removed in Step 2, this is already gone):
```dart
              // Pill removed
```

Delete the comment at line 577:
```dart
          // Crown badge removed by user request
```

- [ ] **Step 4: Remove orphaned route `vocabularyUnitReviewPath` (#11)**

In `lib/app/router.dart`:

Delete lines 100–101 (the static method):
```dart
  static String vocabularyUnitReviewPath(String unitId) =>
      '/vocabulary/unit-review/$unitId';
```

Delete the GoRoute registration at lines 323–329:
```dart
                  GoRoute(
                    path: 'unit-review/:unitId',
                    builder: (context, state) {
                      final unitId = state.pathParameters['unitId']!;
                      return DailyReviewScreen(unitId: unitId);
                    },
                  ),
```

Also remove the `DailyReviewScreen` import if it becomes unused after this deletion (check if other routes still reference it — the `/vocabulary/daily-review` route likely still uses it, so the import stays).

- [ ] **Step 5: Remove duplicate `allAssignmentsProvider` (#13)**

In `owlio_admin/lib/features/learning_path_assignments/screens/assignment_list_screen.dart`:

Delete the duplicate provider definition (lines 12–30):
```dart
/// Fetches all scope learning path assignments with school/class info.
final allAssignmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.scopeLearningPaths)
      .select(
        'id, name, template_id, sort_order, grade, class_id, school_id, '
        'sequential_lock, books_exempt_from_lock, created_at, '
        'schools(id, name), '
        'classes(id, name, grade), '
        'scope_learning_path_units(id, '
        '  vocabulary_units(name), '
        '  scope_unit_items(id, item_type)'
        ')',
      )
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});
```

If `assignment_list_screen.dart` references `allAssignmentsProvider`, add an import to the one defined in `template_list_screen.dart`:
```dart
import '../../../features/templates/screens/template_list_screen.dart' show allAssignmentsProvider;
```

- [ ] **Step 6: Run dart analyze**

Run: `dart analyze lib/` and `dart analyze owlio_admin/lib/`
Expected: No issues found.

---

### Task 4: debugPrint Cleanup (#14)

**Files:**
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart:4,36,46,57,61,71,79,85,88,91`
- Modify: `lib/presentation/providers/teacher_provider.dart:267,271,289`

- [ ] **Step 1: Remove debugPrint calls from `supabase_teacher_repository.dart`**

Remove these 9 `debugPrint` lines from `getTeacherStats` and `getClasses` methods:

```
Line 36:  debugPrint('getTeacherStats: fetching for teacherId=$teacherId');
Line 46:  debugPrint('getTeacherStats: no data returned');
Line 57:  debugPrint('getTeacherStats: result = students:...');
Line 61:  debugPrint('getTeacherStats: PostgrestException = ${e.message}');
Line 71:  debugPrint('getClasses: fetching for schoolId=$schoolId');
Line 79:  debugPrint('getClasses: response = $response');
Line 85:  debugPrint('getClasses: returning ${classes.length} classes');
Line 88:  debugPrint('getClasses: PostgrestException = ${e.message}');
Line 91:  debugPrint('getClasses: Exception = $e');
```

Then check if `import 'package:flutter/foundation.dart';` (line 4) is still needed by other code in the file. If no other `debugPrint` or `foundation.dart` references remain, remove the import. Note: lines 327 and 373 also have `debugPrint` — those log actual error/skip conditions and should be kept. If they remain, keep the import.

- [ ] **Step 2: Remove debugPrint calls from `teacher_provider.dart`**

Remove these 3 `debugPrint` lines:

```
Line 267: debugPrint('📋 classLearningPathUnitsProvider FAILURE: ${failure.message}');
Line 271: debugPrint('📋 classLearningPathUnitsProvider: got ${units.length} units for classId=$classId');
Line 289: debugPrint('📋 studentUnitProgressProvider FAILURE: ${failure.message}');
```

Check if the `debugPrint` import (likely from `package:flutter/foundation.dart`) is still needed. If no other references remain, remove the import.

- [ ] **Step 3: Run dart analyze**

Run: `dart analyze lib/`
Expected: No issues found.

---

### Task 5: Verify, Update Spec, and Commit

**Files:**
- Modify: `docs/specs/07-learning-paths.md` (update finding statuses)

- [ ] **Step 1: Run full dart analyze**

Run: `dart analyze lib/` and `dart analyze owlio_admin/lib/`
Expected: No issues found in either.

- [ ] **Step 2: Verify no raw string itemType comparisons remain**

Run: `grep -rn "itemType == 'word_list'" lib/domain/entities/` and `grep -rn "itemType == 'book'" lib/domain/entities/`
Expected: No matches.

- [ ] **Step 3: Update finding statuses in spec**

In `docs/specs/07-learning-paths.md`, update the Audit Findings table:
- Change Status from `TODO` to `Fixed` for findings: #1, #2, #3, #4, #5, #7, #8, #9, #10, #11, #12, #13, #14, #16, #17, #18, #20
- Change Status from `TODO` to `Known Limitation` for findings: #6, #15, #19, #21

Note on #7: The `GetStudentUnitProgressUseCase` already exists in the codebase (the provider at `teacher_provider.dart:279` already uses `getStudentUnitProgressUseCaseProvider`). Mark as `Fixed (pre-existing)`.

- [ ] **Step 4: Commit all Dart changes**

```bash
git add lib/domain/entities/class_learning_path_unit.dart \
        lib/domain/entities/unit_assignment_item.dart \
        lib/domain/entities/student_unit_progress_item.dart \
        lib/data/models/assignment/class_learning_path_unit_model.dart \
        lib/data/models/assignment/unit_assignment_item_model.dart \
        lib/data/models/assignment/student_unit_progress_item_model.dart \
        lib/data/repositories/supabase/supabase_teacher_repository.dart \
        lib/presentation/providers/teacher_provider.dart \
        lib/presentation/widgets/vocabulary/path_node.dart \
        lib/app/router.dart \
        packages/owlio_shared/lib/src/constants/rpc_functions.dart \
        owlio_admin/lib/features/learning_path_assignments/screens/assignment_list_screen.dart \
        docs/specs/07-learning-paths.md
git commit -m "cleanup: LP audit fixes — enum refactor, dead code removal, debugPrint cleanup (#7-14)"
```
