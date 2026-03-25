# Assignment System Fixes + Unit Assignment Type — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix existing assignment system bugs (dead code, inactive sync, missing RPC, broken mixed type) and add a new `unit` assignment type that lets teachers assign learning path units.

**Architecture:** Extend the existing assignment system by replacing the unused `mixed` type with `unit`. The unit assignment tracks completion of word_list + book items within a scope learning path unit. Three new RPCs handle teacher unit listing, student item listing, and server-side progress calculation.

**Tech Stack:** Flutter/Riverpod, Supabase PostgreSQL RPCs, owlio_shared package

**Spec:** `docs/superpowers/specs/2026-03-26-assignment-system-fixes-and-unit-type-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|----------------|
| `supabase/migrations/20260326000009_assignment_unit_type.sql` | DB: mixed→unit constraint + 4 RPCs |
| `lib/domain/entities/unit_assignment_item.dart` | Entity for unit items with completion state |
| `lib/domain/entities/class_learning_path_unit.dart` | Entity for teacher-side unit selection |
| `lib/domain/usecases/assignment/get_class_learning_path_units_usecase.dart` | UseCase: teacher fetches class units |
| `lib/domain/usecases/student_assignment/get_unit_assignment_items_usecase.dart` | UseCase: student fetches unit items |
| `lib/domain/usecases/student_assignment/calculate_unit_progress_usecase.dart` | UseCase: triggers server-side progress calc |
| `lib/data/models/assignment/class_learning_path_unit_model.dart` | Model: flat RPC rows → entity tree |
| `lib/data/models/assignment/unit_assignment_item_model.dart` | Model: unit item + completion state |

### Modified Files
| File | Changes |
|------|---------|
| `packages/owlio_shared/lib/src/enums/assignment_type.dart` | `mixed` → `unit` |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add 4 RPC constants |
| `lib/domain/entities/student_assignment.dart` | Remove `chapterIds`, add `scopeLpUnitId`, update `mixed` refs |
| `lib/domain/entities/assignment.dart` | Add `scopeLpUnitId` convenience getter |
| `lib/domain/usecases/assignment/create_assignment_usecase.dart` | Add `unit` validation |
| `lib/domain/repositories/teacher_repository.dart` | Add `getClassLearningPathUnits` method |
| `lib/domain/repositories/student_assignment_repository.dart` | Add `getUnitAssignmentItems`, `calculateUnitProgress` |
| `lib/data/repositories/supabase/supabase_teacher_repository.dart` | `getAssignmentDetail` → RPC, add `getClassLearningPathUnits` |
| `lib/data/repositories/supabase/supabase_student_assignment_repository.dart` | Add `getUnitAssignmentItems`, `calculateUnitProgress` |
| `lib/presentation/providers/usecase_providers.dart` | Register new use case providers |
| `lib/presentation/providers/teacher_provider.dart` | Add `classLearningPathUnitsProvider` |
| `lib/presentation/providers/student_assignment_provider.dart` | Activate sync, add unit items provider |
| `lib/presentation/utils/ui_helpers.dart` | `mixed` → `unit` in color/icon helpers |
| `lib/presentation/screens/teacher/create_assignment_screen.dart` | Add Unit segment + unit selection sheet |
| `lib/presentation/screens/teacher/assignment_detail_screen.dart` | Add unit content section |
| `lib/presentation/screens/student/student_assignment_detail_screen.dart` | Add unit item list view |
| `lib/presentation/screens/student/student_assignments_screen.dart` | Watch `assignmentSyncProvider` |
| `lib/presentation/widgets/home/daily_quest_list.dart` | `mixed` → `unit` in icon switch |
| `lib/presentation/providers/book_provider.dart` | Add unit assignment progress trigger |
| `lib/presentation/screens/vocabulary/session_summary_screen.dart` | Add unit assignment progress trigger |

---

### Task 1: Database Migration — Type Constraint + All RPCs

**Files:**
- Create: `supabase/migrations/20260326000009_assignment_unit_type.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- =============================================================================
-- 1. Replace 'mixed' with 'unit' in assignments.type CHECK constraint
-- =============================================================================
ALTER TABLE assignments DROP CONSTRAINT assignments_type_check;
ALTER TABLE assignments ADD CONSTRAINT assignments_type_check
  CHECK (type IN ('book', 'vocabulary', 'unit'));

-- =============================================================================
-- 2. RPC: get_assignment_detail_with_stats (replaces 2-query approach)
-- =============================================================================
CREATE OR REPLACE FUNCTION get_assignment_detail_with_stats(p_assignment_id UUID)
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
DECLARE
  v_teacher_id UUID;
BEGIN
  -- Get the teacher_id for auth check
  SELECT a.teacher_id INTO v_teacher_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION 'Assignment not found: %', p_assignment_id;
  END IF;

  -- Auth: caller must be the teacher or admin
  IF auth.uid() != v_teacher_id AND NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
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
    COUNT(asn.id) AS total_students,
    COUNT(asn.id) FILTER (WHERE asn.status = 'completed') AS completed_students
  FROM assignments a
  LEFT JOIN classes c ON c.id = a.class_id
  LEFT JOIN assignment_students asn ON asn.assignment_id = a.id
  WHERE a.id = p_assignment_id
  GROUP BY a.id, a.teacher_id, a.class_id, c.name, a.type, a.title,
           a.description, a.content_config, a.start_date, a.due_date, a.created_at;
END;
$$;

-- =============================================================================
-- 3. RPC: get_class_learning_path_units (teacher picks a unit to assign)
-- =============================================================================
CREATE OR REPLACE FUNCTION get_class_learning_path_units(p_class_id UUID)
RETURNS TABLE (
  path_id UUID,
  path_name VARCHAR,
  unit_id UUID,
  scope_lp_unit_id UUID,
  unit_name VARCHAR,
  unit_color VARCHAR,
  unit_icon VARCHAR,
  unit_sort_order INTEGER,
  item_type VARCHAR,
  item_id UUID,
  item_sort_order INTEGER,
  word_list_id UUID,
  word_list_name VARCHAR,
  words TEXT[],
  book_id UUID,
  book_title VARCHAR,
  book_chapter_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
BEGIN
  -- Auth: caller must be teacher/admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('teacher', 'admin')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Get school_id and grade from the class
  SELECT cl.school_id, cl.grade INTO v_school_id, v_grade
  FROM classes cl WHERE cl.id = p_class_id;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION 'Class not found: %', p_class_id;
  END IF;

  RETURN QUERY
  SELECT
    slp.id AS path_id,
    slp.name::VARCHAR AS path_name,
    vu.id AS unit_id,
    slpu.id AS scope_lp_unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR,
    sui.id AS item_id,
    sui.sort_order AS item_sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT ARRAY_AGG(vw.word ORDER BY vw.word)
         FROM word_list_items wli
         JOIN vocabulary_words vw ON vw.id = wli.word_id
         WHERE wli.word_list_id = sui.word_list_id)
      ELSE NULL
    END AS words,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL
    END AS book_chapter_count
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = p_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;

-- =============================================================================
-- 4. RPC: get_unit_assignment_items (student sees item list with completion)
-- =============================================================================
CREATE OR REPLACE FUNCTION get_unit_assignment_items(
  p_scope_lp_unit_id UUID,
  p_student_id UUID
)
RETURNS TABLE (
  item_type VARCHAR,
  sort_order INTEGER,
  word_list_id UUID,
  word_list_name VARCHAR,
  word_count BIGINT,
  is_word_list_completed BOOLEAN,
  book_id UUID,
  book_title VARCHAR,
  total_chapters BIGINT,
  completed_chapters BIGINT,
  is_book_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Auth: caller must be the student
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    sui.item_type::VARCHAR,
    sui.sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM word_list_items wli WHERE wli.word_list_id = sui.word_list_id)
      ELSE NULL
    END AS word_count,
    CASE
      WHEN sui.word_list_id IS NOT NULL THEN
        EXISTS (
          SELECT 1 FROM user_word_list_progress uwlp
          WHERE uwlp.user_id = p_student_id
            AND uwlp.word_list_id = sui.word_list_id
            AND uwlp.completed_at IS NOT NULL
        )
      ELSE NULL
    END AS is_word_list_completed,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id)
      ELSE NULL
    END AS total_chapters,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0)
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id)
      ELSE NULL
    END AS completed_chapters,
    CASE
      WHEN sui.book_id IS NOT NULL THEN
        (SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0) >=
                (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id)
         FROM reading_progress rp
         WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id)
      ELSE NULL
    END AS is_book_completed
  FROM scope_unit_items sui
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  WHERE sui.scope_lp_unit_id = p_scope_lp_unit_id
  ORDER BY sui.sort_order;
END;
$$;

-- =============================================================================
-- 5. RPC: calculate_unit_assignment_progress (server-side progress calc)
-- =============================================================================
CREATE OR REPLACE FUNCTION calculate_unit_assignment_progress(
  p_assignment_id UUID,
  p_student_id UUID
)
RETURNS TABLE (progress NUMERIC, completed_count BIGINT, total_count BIGINT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_unit_id UUID;
  v_total BIGINT;
  v_completed BIGINT;
  v_progress NUMERIC;
BEGIN
  -- Auth: caller must be the student
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  -- Get scopeLpUnitId from assignment's content_config
  SELECT (a.content_config->>'scopeLpUnitId')::UUID INTO v_scope_lp_unit_id
  FROM assignments a WHERE a.id = p_assignment_id;

  IF v_scope_lp_unit_id IS NULL THEN
    RAISE EXCEPTION 'Not a unit assignment or assignment not found';
  END IF;

  -- Count total trackable items (word_list + book only)
  SELECT COUNT(*) INTO v_total
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book');

  IF v_total = 0 THEN
    v_progress := 100;
    v_completed := 0;

    RETURN QUERY SELECT v_progress, v_completed, v_total;
    RETURN;
  END IF;

  -- Count completed items
  SELECT COUNT(*) INTO v_completed
  FROM scope_unit_items sui
  WHERE sui.scope_lp_unit_id = v_scope_lp_unit_id
    AND sui.item_type IN ('word_list', 'book')
    AND (
      -- Word list: completed_at is set
      (sui.item_type = 'word_list' AND EXISTS (
        SELECT 1 FROM user_word_list_progress uwlp
        WHERE uwlp.user_id = p_student_id
          AND uwlp.word_list_id = sui.word_list_id
          AND uwlp.completed_at IS NOT NULL
      ))
      OR
      -- Book: all chapters read
      (sui.item_type = 'book' AND (
        SELECT COALESCE(array_length(rp.completed_chapter_ids, 1), 0)
        FROM reading_progress rp
        WHERE rp.user_id = p_student_id AND rp.book_id = sui.book_id
      ) >= (
        SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id
      ))
    );

  v_progress := ROUND((v_completed::NUMERIC / v_total) * 100, 1);

  -- Update assignment_students row
  IF v_progress >= 100 THEN
    UPDATE assignment_students
    SET status = 'completed', progress = 100, score = NULL,
        completed_at = NOW()
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id
      AND status != 'completed';
  ELSE
    UPDATE assignment_students
    SET progress = v_progress,
        status = CASE WHEN status = 'pending' THEN 'in_progress' ELSE status END,
        started_at = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END
    WHERE assignment_id = p_assignment_id AND student_id = p_student_id;
  END IF;

  RETURN QUERY SELECT v_progress, v_completed, v_total;
END;
$$;
```

- [ ] **Step 2: Preview migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run`
Expected: Shows the new migration file will be applied.

- [ ] **Step 3: Push migration**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260326000009_assignment_unit_type.sql
git commit -m "feat(db): add unit assignment type + 4 RPCs

Replace mixed with unit in CHECK constraint.
Add RPCs: get_assignment_detail_with_stats,
get_class_learning_path_units, get_unit_assignment_items,
calculate_unit_assignment_progress."
```

---

### Task 2: Shared Package — Enum + RPC Constants

**Files:**
- Modify: `packages/owlio_shared/lib/src/enums/assignment_type.dart`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Update AssignmentType enum**

Replace `mixed` with `unit` in `packages/owlio_shared/lib/src/enums/assignment_type.dart`:

```dart
/// Types of assignments teachers can create.
enum AssignmentType {
  book,
  vocabulary,
  unit;

  /// Database string representation.
  String get dbValue => name;

  /// Parse from database string.
  static AssignmentType fromDbValue(String value) {
    return AssignmentType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => AssignmentType.book,
    );
  }

  String get displayName {
    switch (this) {
      case AssignmentType.book:
        return 'Book Reading';
      case AssignmentType.vocabulary:
        return 'Vocabulary';
      case AssignmentType.unit:
        return 'Unit';
    }
  }
}
```

- [ ] **Step 2: Add RPC constants**

Add 4 new constants to `packages/owlio_shared/lib/src/constants/rpc_functions.dart` after line 61 (`updateAssignmentProgress`):

```dart
  static const getAssignmentDetailWithStats = 'get_assignment_detail_with_stats';
  static const getClassLearningPathUnits = 'get_class_learning_path_units';
  static const getUnitAssignmentItems = 'get_unit_assignment_items';
  static const calculateUnitAssignmentProgress = 'calculate_unit_assignment_progress';
```

- [ ] **Step 3: Run pub get in shared package**

Run: `cd /Users/wonderelt/Desktop/Owlio/packages/owlio_shared && dart pub get`
Expected: No errors.

- [ ] **Step 4: Run pub get in main app**

Run: `cd /Users/wonderelt/Desktop/Owlio && flutter pub get`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add packages/owlio_shared/lib/src/enums/assignment_type.dart packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(shared): replace mixed with unit assignment type, add 4 RPC constants"
```

---

### Task 3: Domain Layer — Entities + Repository Interfaces

**Files:**
- Modify: `lib/domain/entities/student_assignment.dart`
- Modify: `lib/domain/entities/assignment.dart`
- Create: `lib/domain/entities/unit_assignment_item.dart`
- Create: `lib/domain/entities/class_learning_path_unit.dart`
- Modify: `lib/domain/repositories/teacher_repository.dart`
- Modify: `lib/domain/repositories/student_assignment_repository.dart`

- [ ] **Step 1: Update student_assignment.dart**

In `lib/domain/entities/student_assignment.dart`:

Replace the `StudentAssignmentTypeDisplay` extension (lines 31-46) — change `mixed` to `unit`:

```dart
extension StudentAssignmentTypeDisplay on AssignmentType {
  String get studentDisplayName {
    switch (this) {
      case AssignmentType.book:
        return 'Reading';
      case AssignmentType.vocabulary:
        return 'Vocabulary';
      case AssignmentType.unit:
        return 'Unit';
    }
  }

  /// Backwards compat: fromString maps to fromDbValue.
  static AssignmentType fromString(String value) =>
      AssignmentType.fromDbValue(value);
}
```

Remove the `chapterIds` getter (lines 134-141) and the `mixed` reference in `bookId` getter. Replace lines 118-141 with:

```dart
  /// Get book ID if this is a book assignment
  String? get bookId {
    if (type == StudentAssignmentType.book) {
      return contentConfig['bookId'] as String?;
    }
    return null;
  }

  /// Get word list ID if this is a vocabulary assignment
  String? get wordListId {
    if (type == StudentAssignmentType.vocabulary) {
      return contentConfig['wordListId'] as String?;
    }
    return null;
  }

  /// Get scope learning path unit ID if this is a unit assignment
  String? get scopeLpUnitId {
    if (type == StudentAssignmentType.unit) {
      return contentConfig['scopeLpUnitId'] as String?;
    }
    return null;
  }
```

- [ ] **Step 2: Update assignment.dart — add scopeLpUnitId getter**

Add after line 47 in `lib/domain/entities/assignment.dart`:

```dart
  /// Get scope LP unit ID for unit assignments
  String? get scopeLpUnitId => contentConfig['scopeLpUnitId'] as String?;
```

- [ ] **Step 3: Create unit_assignment_item.dart**

```dart
import 'package:equatable/equatable.dart';

/// A single item within a unit assignment, with student completion state
class UnitAssignmentItem extends Equatable {
  const UnitAssignmentItem({
    required this.itemType,
    required this.sortOrder,
    this.wordListId,
    this.wordListName,
    this.wordCount,
    this.isWordListCompleted,
    this.bookId,
    this.bookTitle,
    this.totalChapters,
    this.completedChapters,
    this.isBookCompleted,
  });

  final String itemType;
  final int sortOrder;
  // Word list fields
  final String? wordListId;
  final String? wordListName;
  final int? wordCount;
  final bool? isWordListCompleted;
  // Book fields
  final String? bookId;
  final String? bookTitle;
  final int? totalChapters;
  final int? completedChapters;
  final bool? isBookCompleted;

  bool get isTracked => itemType == 'word_list' || itemType == 'book';

  bool get isCompleted {
    if (itemType == 'word_list') return isWordListCompleted ?? false;
    if (itemType == 'book') return isBookCompleted ?? false;
    return false;
  }

  @override
  List<Object?> get props => [
    itemType, sortOrder, wordListId, wordListName, wordCount,
    isWordListCompleted, bookId, bookTitle, totalChapters,
    completedChapters, isBookCompleted,
  ];
}
```

- [ ] **Step 4: Create class_learning_path_unit.dart**

```dart
import 'package:equatable/equatable.dart';

/// A unit from the class's learning path, shown to teacher during assignment creation
class ClassLearningPathUnit extends Equatable {
  const ClassLearningPathUnit({
    required this.pathId,
    required this.pathName,
    required this.unitId,
    required this.scopeLpUnitId,
    required this.unitName,
    required this.unitColor,
    required this.unitIcon,
    required this.unitSortOrder,
    required this.items,
  });

  final String pathId;
  final String pathName;
  final String unitId;
  final String scopeLpUnitId;
  final String unitName;
  final String unitColor;
  final String unitIcon;
  final int unitSortOrder;
  final List<ClassLearningPathItem> items;

  /// Count of items that are tracked for progress (word_list + book only)
  int get trackableItemCount =>
      items.where((i) => i.itemType == 'word_list' || i.itemType == 'book').length;

  @override
  List<Object?> get props => [
    pathId, pathName, unitId, scopeLpUnitId, unitName,
    unitColor, unitIcon, unitSortOrder, items,
  ];
}

class ClassLearningPathItem extends Equatable {
  const ClassLearningPathItem({
    required this.itemType,
    required this.sortOrder,
    this.wordListId,
    this.wordListName,
    this.words,
    this.bookId,
    this.bookTitle,
    this.bookChapterCount,
  });

  final String itemType;
  final int sortOrder;
  final String? wordListId;
  final String? wordListName;
  final List<String>? words;
  final String? bookId;
  final String? bookTitle;
  final int? bookChapterCount;

  @override
  List<Object?> get props => [
    itemType, sortOrder, wordListId, wordListName, words,
    bookId, bookTitle, bookChapterCount,
  ];
}
```

- [ ] **Step 5: Update teacher_repository.dart**

Add import at top of `lib/domain/repositories/teacher_repository.dart`:

```dart
import '../entities/class_learning_path_unit.dart';
```

Add method after `deleteAssignment` (after line 63):

```dart
  /// Get learning path units for a class (for unit assignment creation)
  Future<Either<Failure, List<ClassLearningPathUnit>>> getClassLearningPathUnits(
    String classId,
  );
```

- [ ] **Step 6: Update student_assignment_repository.dart**

Add imports at top of `lib/domain/repositories/student_assignment_repository.dart`:

```dart
import '../entities/unit_assignment_item.dart';
```

Add methods after `completeAssignment` (after line 42):

```dart
  /// Get items within a unit assignment with completion state
  Future<Either<Failure, List<UnitAssignmentItem>>> getUnitAssignmentItems(
    String scopeLpUnitId,
    String studentId,
  );

  /// Calculate and update unit assignment progress (server-side)
  Future<Either<Failure, void>> calculateUnitProgress(
    String assignmentId,
    String studentId,
  );
```

- [ ] **Step 7: Verify no compile errors in domain**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/`
Expected: No errors (warnings about missing implementations are expected until data layer is done).

- [ ] **Step 8: Commit**

```bash
git add lib/domain/entities/student_assignment.dart lib/domain/entities/assignment.dart lib/domain/entities/unit_assignment_item.dart lib/domain/entities/class_learning_path_unit.dart lib/domain/repositories/teacher_repository.dart lib/domain/repositories/student_assignment_repository.dart
git commit -m "feat(domain): add unit assignment entities, update repos + remove chapterIds dead code"
```

---

### Task 4: Domain Layer — Use Cases

**Files:**
- Modify: `lib/domain/usecases/assignment/create_assignment_usecase.dart`
- Create: `lib/domain/usecases/assignment/get_class_learning_path_units_usecase.dart`
- Create: `lib/domain/usecases/student_assignment/get_unit_assignment_items_usecase.dart`
- Create: `lib/domain/usecases/student_assignment/calculate_unit_progress_usecase.dart`

- [ ] **Step 1: Update CreateAssignmentUseCase**

In `lib/domain/usecases/assignment/create_assignment_usecase.dart`, add `scopeLpUnitId`, `unitName`, and `totalItems` to `CreateAssignmentParams`:

```dart
class CreateAssignmentParams {
  const CreateAssignmentParams({
    required this.teacherId,
    this.classId,
    this.studentIds,
    required this.type,
    required this.title,
    this.description,
    this.bookId,
    this.wordListId,
    this.lockLibrary = false,
    this.scopeLpUnitId,
    this.unitName,
    this.totalItems,
    required this.startDate,
    required this.dueDate,
  });
  final String teacherId;
  final String? classId;
  final List<String>? studentIds;
  final AssignmentType type;
  final String title;
  final String? description;
  final String? bookId;
  final String? wordListId;
  final bool lockLibrary;
  final String? scopeLpUnitId;
  final String? unitName;
  final int? totalItems;
  final DateTime startDate;
  final DateTime dueDate;
}
```

Update the `call` method to handle `unit` type (add after the vocabulary validation block, before the contentConfig building):

```dart
    if (params.type == AssignmentType.unit && params.scopeLpUnitId == null) {
      return Future.value(
        const Left(ValidationFailure('Unit is required for unit assignments')),
      );
    }
```

Update the contentConfig building section:

```dart
    // Build content config based on type
    final contentConfig = <String, dynamic>{};
    if (params.type == AssignmentType.book) {
      contentConfig['bookId'] = params.bookId;
      contentConfig['lockLibrary'] = params.lockLibrary;
    } else if (params.type == AssignmentType.vocabulary) {
      contentConfig['wordListId'] = params.wordListId;
    } else if (params.type == AssignmentType.unit) {
      contentConfig['scopeLpUnitId'] = params.scopeLpUnitId;
      contentConfig['unitName'] = params.unitName;
      contentConfig['totalItems'] = params.totalItems;
    }
```

- [ ] **Step 2: Create GetClassLearningPathUnitsUseCase**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/class_learning_path_unit.dart';
import '../../repositories/teacher_repository.dart';
import '../usecase.dart';

class GetClassLearningPathUnitsParams {
  const GetClassLearningPathUnitsParams({required this.classId});
  final String classId;
}

class GetClassLearningPathUnitsUseCase
    implements UseCase<List<ClassLearningPathUnit>, GetClassLearningPathUnitsParams> {
  const GetClassLearningPathUnitsUseCase(this._repository);
  final TeacherRepository _repository;

  @override
  Future<Either<Failure, List<ClassLearningPathUnit>>> call(
    GetClassLearningPathUnitsParams params,
  ) {
    return _repository.getClassLearningPathUnits(params.classId);
  }
}
```

- [ ] **Step 3: Create GetUnitAssignmentItemsUseCase**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/unit_assignment_item.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class GetUnitAssignmentItemsParams {
  const GetUnitAssignmentItemsParams({
    required this.scopeLpUnitId,
    required this.studentId,
  });
  final String scopeLpUnitId;
  final String studentId;
}

class GetUnitAssignmentItemsUseCase
    implements UseCase<List<UnitAssignmentItem>, GetUnitAssignmentItemsParams> {
  const GetUnitAssignmentItemsUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, List<UnitAssignmentItem>>> call(
    GetUnitAssignmentItemsParams params,
  ) {
    return _repository.getUnitAssignmentItems(params.scopeLpUnitId, params.studentId);
  }
}
```

- [ ] **Step 4: Create CalculateUnitProgressUseCase**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/student_assignment_repository.dart';
import '../usecase.dart';

class CalculateUnitProgressParams {
  const CalculateUnitProgressParams({
    required this.assignmentId,
    required this.studentId,
  });
  final String assignmentId;
  final String studentId;
}

class CalculateUnitProgressUseCase
    implements UseCase<void, CalculateUnitProgressParams> {
  const CalculateUnitProgressUseCase(this._repository);
  final StudentAssignmentRepository _repository;

  @override
  Future<Either<Failure, void>> call(CalculateUnitProgressParams params) {
    return _repository.calculateUnitProgress(params.assignmentId, params.studentId);
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/assignment/create_assignment_usecase.dart lib/domain/usecases/assignment/get_class_learning_path_units_usecase.dart lib/domain/usecases/student_assignment/get_unit_assignment_items_usecase.dart lib/domain/usecases/student_assignment/calculate_unit_progress_usecase.dart
git commit -m "feat(domain): add unit assignment use cases + update CreateAssignment for unit type"
```

---

### Task 5: Data Layer — Models + Repository Implementations

**Files:**
- Create: `lib/data/models/assignment/class_learning_path_unit_model.dart`
- Create: `lib/data/models/assignment/unit_assignment_item_model.dart`
- Modify: `lib/data/repositories/supabase/supabase_teacher_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_student_assignment_repository.dart`

- [ ] **Step 1: Create ClassLearningPathUnitModel**

```dart
import '../../../domain/entities/class_learning_path_unit.dart';

class ClassLearningPathUnitModel {
  /// Build entity list from flat RPC rows (same pattern as LearningPathModel)
  static List<ClassLearningPathUnit> fromRpcRows(List<dynamic> rows) {
    final Map<String, _UnitBuilder> unitBuilders = {};

    for (final row in rows) {
      final scopeLpUnitId = row['scope_lp_unit_id'] as String;

      unitBuilders.putIfAbsent(scopeLpUnitId, () => _UnitBuilder(
        pathId: row['path_id'] as String,
        pathName: row['path_name'] as String,
        unitId: row['unit_id'] as String,
        scopeLpUnitId: scopeLpUnitId,
        unitName: row['unit_name'] as String,
        unitColor: row['unit_color'] as String? ?? '#6366F1',
        unitIcon: row['unit_icon'] as String? ?? '📚',
        unitSortOrder: (row['unit_sort_order'] as num).toInt(),
      ));

      // Add item if present (item columns may be null for units with no items)
      if (row['item_type'] != null) {
        final wordsRaw = row['words'];
        List<String>? words;
        if (wordsRaw is List) {
          words = wordsRaw.map((e) => e.toString()).toList();
        }

        unitBuilders[scopeLpUnitId]!.items.add(ClassLearningPathItem(
          itemType: row['item_type'] as String,
          sortOrder: (row['item_sort_order'] as num).toInt(),
          wordListId: row['word_list_id'] as String?,
          wordListName: row['word_list_name'] as String?,
          words: words,
          bookId: row['book_id'] as String?,
          bookTitle: row['book_title'] as String?,
          bookChapterCount: (row['book_chapter_count'] as num?)?.toInt(),
        ));
      }
    }

    final units = unitBuilders.values.map((b) => b.build()).toList();
    units.sort((a, b) => a.unitSortOrder.compareTo(b.unitSortOrder));
    return units;
  }
}

class _UnitBuilder {
  _UnitBuilder({
    required this.pathId,
    required this.pathName,
    required this.unitId,
    required this.scopeLpUnitId,
    required this.unitName,
    required this.unitColor,
    required this.unitIcon,
    required this.unitSortOrder,
  });

  final String pathId;
  final String pathName;
  final String unitId;
  final String scopeLpUnitId;
  final String unitName;
  final String unitColor;
  final String unitIcon;
  final int unitSortOrder;
  final List<ClassLearningPathItem> items = [];

  ClassLearningPathUnit build() {
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ClassLearningPathUnit(
      pathId: pathId,
      pathName: pathName,
      unitId: unitId,
      scopeLpUnitId: scopeLpUnitId,
      unitName: unitName,
      unitColor: unitColor,
      unitIcon: unitIcon,
      unitSortOrder: unitSortOrder,
      items: items,
    );
  }
}
```

- [ ] **Step 2: Create UnitAssignmentItemModel**

```dart
import '../../../domain/entities/unit_assignment_item.dart';

class UnitAssignmentItemModel {
  static UnitAssignmentItem fromJson(Map<String, dynamic> json) {
    return UnitAssignmentItem(
      itemType: json['item_type'] as String,
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
}
```

- [ ] **Step 3: Update supabase_teacher_repository.dart**

Add import at top:

```dart
import '../../models/assignment/class_learning_path_unit_model.dart';
```

Replace `getAssignmentDetail` method (lines 279-314) with:

```dart
  @override
  Future<Either<Failure, Assignment>> getAssignmentDetail(String assignmentId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getAssignmentDetailWithStats,
        params: {'p_assignment_id': assignmentId},
      );

      final rows = response as List;
      if (rows.isEmpty) {
        return const Left(NotFoundFailure('Assignment not found'));
      }

      return Right(AssignmentModel.fromJson(rows.first as Map<String, dynamic>).toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

Add `getClassLearningPathUnits` method after `deleteAssignment` (after line 391):

```dart
  @override
  Future<Either<Failure, List<ClassLearningPathUnit>>> getClassLearningPathUnits(
    String classId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getClassLearningPathUnits,
        params: {'p_class_id': classId},
      );

      final units = ClassLearningPathUnitModel.fromRpcRows(response as List);
      return Right(units);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 4: Update supabase_student_assignment_repository.dart**

Add import at top:

```dart
import '../../models/assignment/unit_assignment_item_model.dart';
import '../../../domain/entities/unit_assignment_item.dart';
```

Add methods at the end of the class (before closing `}`):

```dart
  @override
  Future<Either<Failure, List<UnitAssignmentItem>>> getUnitAssignmentItems(
    String scopeLpUnitId,
    String studentId,
  ) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.getUnitAssignmentItems,
        params: {
          'p_scope_lp_unit_id': scopeLpUnitId,
          'p_student_id': studentId,
        },
      );

      final items = (response as List)
          .map((data) => UnitAssignmentItemModel.fromJson(data as Map<String, dynamic>))
          .toList();
      return Right(items);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> calculateUnitProgress(
    String assignmentId,
    String studentId,
  ) async {
    try {
      await _supabase.rpc(
        RpcFunctions.calculateUnitAssignmentProgress,
        params: {
          'p_assignment_id': assignmentId,
          'p_student_id': studentId,
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

- [ ] **Step 5: Verify compilation**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/data/`
Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/assignment/class_learning_path_unit_model.dart lib/data/models/assignment/unit_assignment_item_model.dart lib/data/repositories/supabase/supabase_teacher_repository.dart lib/data/repositories/supabase/supabase_student_assignment_repository.dart
git commit -m "feat(data): add unit assignment models + update repos for RPC + new methods"
```

---

### Task 6: Presentation Layer — Providers

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/teacher_provider.dart`
- Modify: `lib/presentation/providers/student_assignment_provider.dart`

- [ ] **Step 1: Register new use case providers**

In `lib/presentation/providers/usecase_providers.dart`, add after the `createAssignmentUseCaseProvider` (after line 208):

```dart
final getClassLearningPathUnitsUseCaseProvider = Provider((ref) {
  return GetClassLearningPathUnitsUseCase(ref.watch(teacherRepositoryProvider));
});
```

Add after the `completeAssignmentUseCaseProvider` (after line 627):

```dart
final getUnitAssignmentItemsUseCaseProvider = Provider((ref) {
  return GetUnitAssignmentItemsUseCase(ref.watch(studentAssignmentRepositoryProvider));
});

final calculateUnitProgressUseCaseProvider = Provider((ref) {
  return CalculateUnitProgressUseCase(ref.watch(studentAssignmentRepositoryProvider));
});
```

Add the necessary imports at the top of the file:

```dart
import '../../domain/usecases/assignment/get_class_learning_path_units_usecase.dart';
import '../../domain/usecases/student_assignment/get_unit_assignment_items_usecase.dart';
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
```

- [ ] **Step 2: Add teacher provider for class units**

In `lib/presentation/providers/teacher_provider.dart`, add after the `assignmentStudentsProvider` (after line 221):

```dart
/// Provider for learning path units of a class (for unit assignment creation)
final classLearningPathUnitsProvider =
    FutureProvider.family<List<ClassLearningPathUnit>, String>((ref, classId) async {
  final useCase = ref.watch(getClassLearningPathUnitsUseCaseProvider);
  final result = await useCase(GetClassLearningPathUnitsParams(classId: classId));

  return result.fold(
    (failure) => [],
    (units) => units,
  );
});
```

Add import at top:

```dart
import '../../domain/entities/class_learning_path_unit.dart';
import '../../domain/usecases/assignment/get_class_learning_path_units_usecase.dart';
```

- [ ] **Step 3: Update student_assignment_provider.dart**

Add unit items provider and activate sync. In `lib/presentation/providers/student_assignment_provider.dart`, add import:

```dart
import '../../domain/entities/unit_assignment_item.dart';
import '../../domain/usecases/student_assignment/get_unit_assignment_items_usecase.dart';
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
```

Add after `assignmentSyncProvider` (after line 138, before the closing of the file):

```dart

/// Provider for unit assignment items (student detail screen)
final unitAssignmentItemsProvider =
    FutureProvider.family<List<UnitAssignmentItem>, ({String scopeLpUnitId, String studentId})>(
  (ref, params) async {
    final useCase = ref.watch(getUnitAssignmentItemsUseCaseProvider);
    final result = await useCase(GetUnitAssignmentItemsParams(
      scopeLpUnitId: params.scopeLpUnitId,
      studentId: params.studentId,
    ));

    return result.fold(
      (failure) => [],
      (items) => items,
    );
  },
);
```

Extend `assignmentSyncProvider` to also handle unit assignments. Replace lines 98-127 (the for loop body inside `assignmentSyncProvider`) with:

```dart
  for (final assignment in assignments) {
    if (assignment.status == StudentAssignmentStatus.completed) continue;

    // Sync book assignments
    if (assignment.bookId != null) {
      final progressResult = await getReadingProgressUseCase(
        GetReadingProgressParams(userId: userId, bookId: assignment.bookId!),
      );

      final isBookCompleted = progressResult.fold(
        (failure) => false,
        (progress) => progress.isCompleted,
      );

      if (isBookCompleted) {
        debugPrint('🔄 Syncing: Assignment "${assignment.title}" - book is completed but assignment not');
        await completeAssignmentUseCase(CompleteAssignmentParams(
          studentId: userId,
          assignmentId: assignment.assignmentId,
          score: null,
        ));
        syncedCount++;
      }
    }

    // Sync unit assignments
    if (assignment.scopeLpUnitId != null) {
      debugPrint('🔄 Syncing unit assignment: "${assignment.title}"');
      final calculateUseCase = ref.read(calculateUnitProgressUseCaseProvider);
      await calculateUseCase(CalculateUnitProgressParams(
        assignmentId: assignment.assignmentId,
        studentId: userId,
      ));
      syncedCount++;
    }
  }
```

- [ ] **Step 4: Verify compilation**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/usecase_providers.dart lib/presentation/providers/teacher_provider.dart lib/presentation/providers/student_assignment_provider.dart
git commit -m "feat(providers): register unit assignment providers + activate sync + unit items provider"
```

---

### Task 7: Presentation Layer — UI Helpers + Home Screen

**Files:**
- Modify: `lib/presentation/utils/ui_helpers.dart`
- Modify: `lib/presentation/widgets/home/daily_quest_list.dart`

- [ ] **Step 1: Update AssignmentColors in ui_helpers.dart**

Replace `mixed` with `unit` in both `AssignmentColors` and `StudentAssignmentColors`. In `lib/presentation/utils/ui_helpers.dart`:

Replace lines 19-21 (`AssignmentColors.getTypeColor` mixed case):
```dart
      case AssignmentType.unit:
        return Colors.orange;
```

Replace lines 30-31 (`AssignmentColors.getTypeIcon` mixed case):
```dart
      case AssignmentType.unit:
        return Icons.route;
```

Replace lines 70-71 (`StudentAssignmentColors.getTypeColor` mixed case):
```dart
      case StudentAssignmentType.unit:
        return Colors.orange;
```

Replace lines 81-82 (`StudentAssignmentColors.getTypeIcon` mixed case):
```dart
      case StudentAssignmentType.unit:
        return Icons.route;
```

- [ ] **Step 2: Update daily_quest_list.dart**

In `lib/presentation/widgets/home/daily_quest_list.dart`, replace lines 531-533 (the `mixed` case in `_AssignmentQuestRow`):

```dart
      case StudentAssignmentType.unit:
        icon = Icons.route;
        iconColor = AppColors.tertiary;
```

(Use `AppColors.tertiary` or another orange-ish color that exists in AppColors — check the theme file. If `AppColors.tertiary` doesn't exist, use `const Color(0xFFFF9800)` — Material orange.)

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/utils/ lib/presentation/widgets/home/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/utils/ui_helpers.dart lib/presentation/widgets/home/daily_quest_list.dart
git commit -m "feat(ui): update assignment colors/icons — mixed → unit"
```

---

### Task 8: Teacher Create Assignment Screen — Unit Type

**Files:**
- Modify: `lib/presentation/screens/teacher/create_assignment_screen.dart`

- [ ] **Step 1: Add state variables for unit selection**

In `_CreateAssignmentScreenState`, add after line 53 (`_selectedWordListName`):

```dart
  // For unit assignments
  String? _selectedScopeLpUnitId;
  String? _selectedUnitName;
  int? _selectedUnitTotalItems;
```

- [ ] **Step 2: Add Unit to SegmentedButton**

Replace the `SegmentedButton` (lines 231-257) with:

```dart
            SegmentedButton<AssignmentType>(
              segments: const [
                ButtonSegment(
                  value: AssignmentType.book,
                  label: Text('Book'),
                  icon: Icon(Icons.menu_book),
                ),
                ButtonSegment(
                  value: AssignmentType.vocabulary,
                  label: Text('Vocabulary'),
                  icon: Icon(Icons.abc),
                ),
                ButtonSegment(
                  value: AssignmentType.unit,
                  label: Text('Unit'),
                  icon: Icon(Icons.route),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<AssignmentType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                  // Clear selections when type changes
                  _selectedBookId = null;
                  _selectedBookTitle = null;
                  _selectedBookChapterCount = null;
                  _lockLibrary = false;
                  _selectedWordListId = null;
                  _selectedWordListName = null;
                  _selectedScopeLpUnitId = null;
                  _selectedUnitName = null;
                  _selectedUnitTotalItems = null;
                });
              },
            ),
```

- [ ] **Step 3: Add unit content selection UI**

Add after the vocabulary content selection section (after line 472, before `const SizedBox(height: 32)`):

```dart
            // Unit content selection
            if (_selectedType == AssignmentType.unit) ...[
              Text(
                'Unit Content',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedClassId == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Please select a class first to see available units',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.route,
                      color: _selectedScopeLpUnitId != null
                          ? context.colorScheme.primary
                          : context.colorScheme.outline,
                    ),
                    title: Text(
                      _selectedScopeLpUnitId != null
                          ? _selectedUnitName ?? 'Unit selected'
                          : 'Select Unit',
                    ),
                    subtitle: Text(
                      _selectedScopeLpUnitId != null
                          ? '${_selectedUnitTotalItems ?? 0} trackable items'
                          : 'Tap to choose a learning path unit',
                      style: TextStyle(
                        color: _selectedScopeLpUnitId != null
                            ? context.colorScheme.primary
                            : context.colorScheme.outline,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showUnitSelectionSheet(context, ref),
                  ),
                ),
            ],
```

- [ ] **Step 4: Add unit selection bottom sheet method**

Add after `_showWordListSelectionSheet` (after line 207):

```dart
  Future<void> _showUnitSelectionSheet(BuildContext context, WidgetRef ref) async {
    if (_selectedClassId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _UnitSelectionSheet(
          scrollController: scrollController,
          classId: _selectedClassId!,
          selectedScopeLpUnitId: _selectedScopeLpUnitId,
          onUnitSelected: (scopeLpUnitId, unitName, totalItems) {
            setState(() {
              _selectedScopeLpUnitId = scopeLpUnitId;
              _selectedUnitName = unitName;
              _selectedUnitTotalItems = totalItems;
            });
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }
```

- [ ] **Step 5: Update _createAssignment to pass unit params**

Replace the `useCase` call in `_createAssignment` (lines 117-130):

```dart
      final useCase = ref.read(createAssignmentUseCaseProvider);
      final result = await useCase(CreateAssignmentParams(
        teacherId: userId,
        classId: _selectedClassId,
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        bookId: _selectedBookId,
        wordListId: _selectedWordListId,
        lockLibrary: _lockLibrary,
        scopeLpUnitId: _selectedScopeLpUnitId,
        unitName: _selectedUnitName,
        totalItems: _selectedUnitTotalItems,
        startDate: _startDate,
        dueDate: _dueDate,
      ));
```

- [ ] **Step 6: Add _UnitSelectionSheet widget**

Add at the end of the file (after `_WordListSelectionSheet`):

```dart
// =============================================
// UNIT SELECTION SHEET
// =============================================

class _UnitSelectionSheet extends ConsumerWidget {
  const _UnitSelectionSheet({
    required this.scrollController,
    required this.classId,
    required this.selectedScopeLpUnitId,
    required this.onUnitSelected,
  });

  final ScrollController scrollController;
  final String classId;
  final String? selectedScopeLpUnitId;
  final void Function(String scopeLpUnitId, String unitName, int totalItems) onUnitSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(classLearningPathUnitsProvider(classId));

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: context.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Select Unit',
                  style: context.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: unitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading units')),
            data: (units) {
              if (units.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No learning path assigned to this class yet.\nAsk an admin to assign a learning path.',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: units.length,
                itemBuilder: (context, index) {
                  final unit = units[index];
                  final isSelected = selectedScopeLpUnitId == unit.scopeLpUnitId;

                  return _UnitCard(
                    unit: unit,
                    isSelected: isSelected,
                    onTap: () => onUnitSelected(
                      unit.scopeLpUnitId,
                      unit.unitName,
                      unit.trackableItemCount,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.isSelected,
    required this.onTap,
  });

  final ClassLearningPathUnit unit;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unitColor = VocabularyUnitColor.fromHex(unit.unitColor);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: context.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unit header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: unitColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(unit.unitIcon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.unitName,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? context.colorScheme.primary : null,
                          ),
                        ),
                        Text(
                          '${unit.items.length} items (${unit.trackableItemCount} tracked)',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: context.colorScheme.primary),
                ],
              ),

              // Item list
              const SizedBox(height: 12),
              ...unit.items.map((item) => _UnitItemRow(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitItemRow extends StatelessWidget {
  const _UnitItemRow({required this.item});

  final ClassLearningPathItem item;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final String? subtitle;

    switch (item.itemType) {
      case 'word_list':
        icon = Icons.abc;
        label = item.wordListName ?? 'Word List';
        subtitle = item.words != null ? item.words!.join(', ') : null;
      case 'book':
        icon = Icons.menu_book;
        label = item.bookTitle ?? 'Book';
        subtitle = '${item.bookChapterCount ?? 0} chapters';
      case 'game':
        icon = Icons.sports_esports;
        label = 'Game';
        subtitle = 'Not graded';
      case 'treasure':
        icon = Icons.card_giftcard;
        label = 'Treasure';
        subtitle = 'Not graded';
      default:
        icon = Icons.help;
        label = item.itemType;
        subtitle = null;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: context.textTheme.labelSmall?.copyWith(color: context.colorScheme.outline),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Add necessary import at top:

```dart
import '../../providers/teacher_provider.dart';
```

(This import already exists — just make sure `classLearningPathUnitsProvider` is accessible.)

- [ ] **Step 7: Verify compilation**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/screens/teacher/create_assignment_screen.dart`
Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/teacher/create_assignment_screen.dart
git commit -m "feat(teacher): add Unit type to create assignment screen with unit selection sheet"
```

---

### Task 9: Teacher Assignment Detail — Unit Content Section

**Files:**
- Modify: `lib/presentation/screens/teacher/assignment_detail_screen.dart`

- [ ] **Step 1: Add unit content section**

In `lib/presentation/screens/teacher/assignment_detail_screen.dart`, add a unit content sliver between the stats bar and the "Student Progress" section header. Insert after the `_StatsBar` sliver (after line 51) and before the section header sliver (line 54):

```dart
              // Unit content (if unit assignment)
              if (assignment.type == AssignmentType.unit && assignment.scopeLpUnitId != null)
                SliverToBoxAdapter(
                  child: _UnitContentSection(
                    classId: assignment.classId,
                    scopeLpUnitId: assignment.scopeLpUnitId!,
                  ),
                ),
```

Add the `_UnitContentSection` widget at the end of the file (before the closing):

```dart
class _UnitContentSection extends ConsumerWidget {
  const _UnitContentSection({
    required this.classId,
    required this.scopeLpUnitId,
  });

  final String? classId;
  final String scopeLpUnitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (classId == null) return const SizedBox.shrink();

    final unitsAsync = ref.watch(classLearningPathUnitsProvider(classId!));

    return unitsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (units) {
        final unit = units.where((u) => u.scopeLpUnitId == scopeLpUnitId).firstOrNull;
        if (unit == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit Content',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: unit.items.map((item) {
                      final IconData icon;
                      final String label;
                      final String? detail;
                      final bool isTracked;

                      switch (item.itemType) {
                        case 'word_list':
                          icon = Icons.abc;
                          label = item.wordListName ?? 'Word List';
                          detail = '${item.words?.length ?? 0} words';
                          isTracked = true;
                        case 'book':
                          icon = Icons.menu_book;
                          label = item.bookTitle ?? 'Book';
                          detail = '${item.bookChapterCount ?? 0} chapters';
                          isTracked = true;
                        case 'game':
                          icon = Icons.sports_esports;
                          label = 'Game';
                          detail = 'Not graded';
                          isTracked = false;
                        case 'treasure':
                          icon = Icons.card_giftcard;
                          label = 'Treasure';
                          detail = 'Not graded';
                          isTracked = false;
                        default:
                          icon = Icons.help;
                          label = item.itemType;
                          detail = null;
                          isTracked = false;
                      }

                      return ListTile(
                        dense: true,
                        leading: Icon(icon, size: 20, color: isTracked ? null : context.colorScheme.outline),
                        title: Text(
                          label,
                          style: TextStyle(
                            color: isTracked ? null : context.colorScheme.outline,
                          ),
                        ),
                        trailing: detail != null
                            ? Text(
                                detail,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.outline,
                                ),
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

Add import at top:

```dart
import '../../providers/teacher_provider.dart' show classLearningPathUnitsProvider;
```

- [ ] **Step 2: Commit**

```bash
git add lib/presentation/screens/teacher/assignment_detail_screen.dart
git commit -m "feat(teacher): show unit content in assignment detail screen"
```

---

### Task 10: Student Assignment Detail — Unit Item List

**Files:**
- Modify: `lib/presentation/screens/student/student_assignment_detail_screen.dart`

- [ ] **Step 1: Update "What to Do" section for unit type**

In `lib/presentation/screens/student/student_assignment_detail_screen.dart`, replace the "What to Do" sliver (lines 348-389) with:

```dart
        // Content to complete
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What to Do',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (assignment.type == StudentAssignmentType.book) ...[
                  _ContentCard(
                    icon: Icons.menu_book,
                    title: 'Read assigned book',
                    subtitle: 'Complete all chapters',
                    color: Colors.blue,
                    onTap: assignment.bookId != null
                        ? () => _startReading(context, ref, assignment)
                        : null,
                  ),
                ],
                if (assignment.type == StudentAssignmentType.vocabulary) ...[
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
                if (assignment.type == StudentAssignmentType.unit) ...[
                  _UnitItemsList(assignment: assignment),
                ],
              ],
            ),
          ),
        ),
```

- [ ] **Step 2: Add _UnitItemsList widget**

Add before the `_ContentCard` class (before line 449):

```dart
class _UnitItemsList extends ConsumerWidget {
  const _UnitItemsList({required this.assignment});

  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null || assignment.scopeLpUnitId == null) {
      return const SizedBox.shrink();
    }

    final itemsAsync = ref.watch(unitAssignmentItemsProvider(
      (scopeLpUnitId: assignment.scopeLpUnitId!, studentId: userId),
    ));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error loading unit items'),
      data: (items) {
        return Column(
          children: items.map((item) {
            final IconData icon;
            final String title;
            final String subtitle;
            final Color color;
            final bool isTracked = item.isTracked;
            final bool isCompleted = item.isCompleted;
            VoidCallback? onTap;

            switch (item.itemType) {
              case 'word_list':
                icon = Icons.abc;
                title = item.wordListName ?? 'Word List';
                subtitle = '${item.wordCount ?? 0} words';
                color = Colors.purple;
                if (item.wordListId != null) {
                  onTap = () => _startUnitItem(context, ref, assignment, wordListId: item.wordListId);
                }
              case 'book':
                icon = Icons.menu_book;
                title = item.bookTitle ?? 'Book';
                subtitle = '${item.completedChapters ?? 0}/${item.totalChapters ?? 0} chapters';
                color = Colors.blue;
                if (item.bookId != null) {
                  onTap = () => _startUnitItem(context, ref, assignment, bookId: item.bookId);
                }
              case 'game':
                icon = Icons.sports_esports;
                title = 'Game';
                subtitle = 'Not graded';
                color = Colors.grey;
              case 'treasure':
                icon = Icons.card_giftcard;
                title = 'Treasure';
                subtitle = 'Not graded';
                color = Colors.grey;
              default:
                icon = Icons.help;
                title = item.itemType;
                subtitle = '';
                color = Colors.grey;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isTracked ? color : Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: isTracked ? color : Colors.grey, size: 20),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isTracked ? null : context.colorScheme.outline,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.outline,
                  ),
                ),
                trailing: isTracked
                    ? Icon(
                        isCompleted ? Icons.check_circle : Icons.arrow_forward,
                        color: isCompleted ? Colors.green : color,
                      )
                    : Text(
                        'not graded',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.outline,
                        ),
                      ),
                onTap: isTracked ? onTap : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _startUnitItem(
    BuildContext context,
    WidgetRef ref,
    StudentAssignment assignment, {
    String? wordListId,
    String? bookId,
  }) async {
    // Start assignment if pending
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

    if (!context.mounted) return;

    if (wordListId != null) {
      context.go(AppRoutes.vocabularyListPath(wordListId));
    } else if (bookId != null) {
      context.go(AppRoutes.bookDetailPath(bookId));
    }
  }
}
```

Add import at top:

```dart
import '../../providers/student_assignment_provider.dart' show unitAssignmentItemsProvider;
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/student/student_assignment_detail_screen.dart
git commit -m "feat(student): show unit item list with completion state in assignment detail"
```

---

### Task 11: Assignment Progress Triggers — Book + Vocabulary

**Files:**
- Modify: `lib/presentation/providers/book_provider.dart`
- Modify: `lib/presentation/screens/vocabulary/session_summary_screen.dart`

- [ ] **Step 1: Add unit assignment trigger in book_provider.dart**

In `lib/presentation/providers/book_provider.dart`, inside `_updateAssignmentProgress`, after the existing for-loop that handles book assignments (after line 291, before the catch block), add:

```dart
      // Also check unit assignments that might contain this book
      for (final assignment in assignments) {
        if (assignment.scopeLpUnitId != null &&
            assignment.status != StudentAssignmentStatus.completed) {
          debugPrint('📋 Unit assignment found: ${assignment.title}, recalculating progress');
          final calculateUseCase = _ref.read(calculateUnitProgressUseCaseProvider);
          await calculateUseCase(CalculateUnitProgressParams(
            assignmentId: assignment.assignmentId,
            studentId: userId,
          ));
          _ref.invalidate(studentAssignmentsProvider);
          _ref.invalidate(activeAssignmentsProvider);
          _ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }
```

Add import at top of file:

```dart
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
```

- [ ] **Step 2: Add unit assignment trigger in session_summary_screen.dart**

In `lib/presentation/screens/vocabulary/session_summary_screen.dart`, inside `_completeVocabularyAssignment`, after the existing for-loop (after line 189, before the catch block), add:

```dart
      // Also check unit assignments
      for (final assignment in assignments) {
        if (assignment.scopeLpUnitId != null &&
            assignment.status != StudentAssignmentStatus.completed) {
          debugPrint('📋 Unit assignment found: ${assignment.title}, recalculating progress');
          final calculateUseCase = ref.read(calculateUnitProgressUseCaseProvider);
          await calculateUseCase(CalculateUnitProgressParams(
            assignmentId: assignment.assignmentId,
            studentId: userId,
          ));
          ref.invalidate(studentAssignmentsProvider);
          ref.invalidate(activeAssignmentsProvider);
          ref.invalidate(studentAssignmentDetailProvider(assignment.assignmentId));
        }
      }
```

Add import at top of file:

```dart
import '../../domain/usecases/student_assignment/calculate_unit_progress_usecase.dart';
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/providers/book_provider.dart lib/presentation/screens/vocabulary/session_summary_screen.dart
git commit -m "feat(student): trigger unit assignment progress calc on chapter/vocab completion"
```

---

### Task 12: Activate assignmentSyncProvider + Final Wiring

**Files:**
- Modify: `lib/presentation/screens/student/student_assignments_screen.dart`

- [ ] **Step 1: Watch assignmentSyncProvider**

In `lib/presentation/screens/student/student_assignments_screen.dart`, find the `build` method of the screen widget and add `ref.watch(assignmentSyncProvider)` at the start of the build method. This needs to be inside a `ConsumerWidget` or `ConsumerStatefulWidget` build. Find the appropriate place and add:

```dart
    // Sync any assignments that should be auto-completed
    ref.watch(assignmentSyncProvider);
```

- [ ] **Step 2: Run full analysis**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/student/student_assignments_screen.dart
git commit -m "feat(student): activate assignmentSyncProvider on assignments screen"
```

---

### Task 13: Final Verification

- [ ] **Step 1: Run dart analyze on entire project**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: 0 errors.

- [ ] **Step 2: Check no raw 'mixed' string references remain**

Run: `grep -r "mixed" lib/ --include="*.dart" | grep -i assignment`
Expected: No results referencing the old `mixed` assignment type. (Generic Dart `mixed` usage unrelated to assignments is fine.)

- [ ] **Step 3: Check no direct repository usage in screens**

Run: `grep -r "ref\.\(read\|watch\).*RepositoryProvider" lib/presentation/screens/ | wc -l`
Expected: 0

- [ ] **Step 4: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "chore: final cleanup for assignment system fixes + unit type"
```
