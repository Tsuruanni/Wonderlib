# Class Grade Enforcement

**Date:** 2026-03-27
**Status:** Spec
**Root Cause:** User in class "Test-A" (grade: null) gets 0 learning paths because `get_user_learning_paths` RPC can't match grade-scoped paths when `classes.grade IS NULL`.

---

## Problem

The `classes.grade` column is nullable and not enforced anywhere:

| Layer | Grade status |
|-------|-------------|
| DB schema | `INTEGER` — nullable, no NOT NULL |
| Teacher app (create class dialog) | Grade field **not in the form at all** |
| Admin panel (create/edit class) | Grade field present, **no validation** |
| `CreateClassUseCase` params | **No grade parameter** |
| `createClass` repository method | **Doesn't send grade to DB** |
| `update_class` RPC | **Can't update grade** |

This breaks `get_user_learning_paths` RPC which does:

```sql
SELECT p.school_id, c.grade, p.class_id
FROM profiles p LEFT JOIN classes c ON c.id = p.class_id
WHERE p.id = p_user_id;

-- Then matches:
WHERE slp.grade = v_grade       -- fails when v_grade IS NULL
  OR  slp.class_id = v_class_id -- fails when no class-specific path exists
  OR  (slp.grade IS NULL AND slp.class_id IS NULL) -- only matches school-wide paths
```

A student in a class with `grade = null` can ONLY see school-wide learning paths (grade=null, class_id=null). Grade-scoped paths are invisible.

---

## Fix 1: DB — Make `classes.grade` NOT NULL

### Migration

```sql
-- Fix null grades and enforce NOT NULL + range constraint
DO $$
DECLARE
  r RECORD;
  v_extracted INT;
BEGIN
  FOR r IN SELECT id, name, school_id FROM classes WHERE grade IS NULL LOOP
    -- Try to extract grade from class name (e.g., "5-A" → 5, "6-A" → 6)
    v_extracted := (regexp_match(r.name, '^(\d+)'))[1]::INT;
    IF v_extracted IS NOT NULL AND v_extracted BETWEEN 1 AND 12 THEN
      UPDATE classes SET grade = v_extracted WHERE id = r.id;
      RAISE NOTICE 'Auto-fixed class "%" → grade %', r.name, v_extracted;
    ELSE
      -- Can't auto-detect, set to 5 as safe default for this project
      UPDATE classes SET grade = 5 WHERE id = r.id;
      RAISE NOTICE 'WARNING: Set class "%" to default grade 5 — review needed', r.name;
    END IF;
  END LOOP;
END $$;

ALTER TABLE classes ALTER COLUMN grade SET NOT NULL;
ALTER TABLE classes ADD CONSTRAINT classes_grade_range CHECK (grade BETWEEN 1 AND 12);
```

---

## Fix 2: `update_class` RPC — Add grade parameter

Used by the teacher app (via `UpdateClassUseCase`). The admin panel bypasses this RPC and uses direct Supabase `.update()` — it already sends grade in its data map, so the DB NOT NULL constraint covers it.

### Current

```sql
CREATE OR REPLACE FUNCTION update_class(
  p_class_id UUID, p_name TEXT, p_description TEXT DEFAULT NULL
) ...
  UPDATE classes SET name = p_name, description = p_description
  WHERE classes.id = p_class_id;
```

### Updated

```sql
CREATE OR REPLACE FUNCTION update_class(
  p_class_id UUID,
  p_name TEXT,
  p_grade INTEGER,
  p_description TEXT DEFAULT NULL
) ...
  UPDATE classes SET name = p_name, grade = p_grade, description = p_description
  WHERE classes.id = p_class_id;
```

---

## Fix 3: `CreateClassUseCase` — Add required grade parameter

### `create_class_usecase.dart`

```dart
class CreateClassParams {
  const CreateClassParams({
    required this.schoolId,
    required this.name,
    required this.grade,    // NEW — required
    this.description,
  });
  final String schoolId;
  final String name;
  final int grade;          // NEW
  final String? description;
}
```

### `teacher_repository.dart` (interface)

```dart
Future<Either<Failure, String>> createClass({
  required String schoolId,
  required String name,
  required int grade,       // NEW
  String? description,
});
```

### `supabase_teacher_repository.dart` (implementation)

```dart
final response = await _supabase.from(DbTables.classes).insert({
  'school_id': schoolId,
  'name': name,
  'grade': grade,           // NEW
  'description': description,
}).select('id').single();
```

---

## Fix 4: `UpdateClassUseCase` — Add grade parameter

### Current `updateClass` in repository

Only sends `name` and `description` to the RPC.

### Updated

```dart
// teacher_repository.dart (interface)
Future<Either<Failure, void>> updateClass({
  required String classId,
  required String name,
  required int grade,       // NEW
  String? description,
});

// supabase_teacher_repository.dart
await _supabase.rpc(RpcFunctions.updateClass, params: {
  'p_class_id': classId,
  'p_name': name,
  'p_grade': grade,         // NEW
  'p_description': description,
});
```

### `update_class_usecase.dart` (exists)

Add `required int grade` to `UpdateClassParams`. Update `call()` to pass `grade` to repository.

---

## Fix 5: Teacher App — Add grade dropdown to create class dialog

### `classes_screen.dart` — `_showCreateClassDialog`

Add a grade dropdown (1-12) above the description field. Required field.

```dart
DropdownButtonFormField<int>(
  decoration: const InputDecoration(
    labelText: 'Grade *',
    border: OutlineInputBorder(),
  ),
  items: List.generate(12, (i) => DropdownMenuItem(
    value: i + 1,
    child: Text('Grade ${i + 1}'),
  )),
  validator: (value) => value == null ? 'Please select a grade' : null,
  onChanged: (value) => selectedGrade = value,
),
```

### `classes_screen.dart` — `_showEditClassDialog`

This dialog currently only has a name field. Add the same grade dropdown (pre-populated with `classItem.grade`), and pass grade to `UpdateClassParams`.

---

## Fix 6: Admin Panel — Add grade validation

### `class_edit_screen.dart`

Change the grade `TextFormField` to:
1. Add a required validator
2. Validate range 1-12

```dart
TextFormField(
  controller: _gradeController,
  decoration: const InputDecoration(
    labelText: 'Sınıf Seviyesi *',
    hintText: 'ör. 5, 7, 12',
  ),
  keyboardType: TextInputType.number,
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Sınıf seviyesi zorunludur';
    }
    final grade = int.tryParse(value.trim());
    if (grade == null || grade < 1 || grade > 12) {
      return '1-12 arası bir değer girin';
    }
    return null;
  },
),
```

---

## Note: `get_user_learning_paths` RPC

No change needed. The school-wide match `(slp.grade IS NULL AND slp.class_id IS NULL)` already works regardless of v_grade. The root cause is fixed at data level — the NOT NULL constraint on classes.grade ensures v_grade is always populated.

---

## Fix 7: `TeacherClass` entity — Make grade non-nullable

### `teacher.dart`

```dart
// Before
final int? grade;

// After
final int grade;
```

### `teacher_class_model.dart`

Update `fromJson` to parse grade as non-nullable `int`:
```dart
// Before
grade: json['grade'] as int?,

// After
grade: json['grade'] as int,
```

---

## Summary of Changes

| File | Change |
|------|--------|
| **New migration** | Fix null grades, add NOT NULL + CHECK(1-12) |
| **New migration** | Update `update_class` RPC to accept grade |
| `create_class_usecase.dart` | Add `required int grade` param |
| `update_class_usecase.dart` | Add `required int grade` param |
| `teacher_repository.dart` | Add `required int grade` to `createClass` and `updateClass` |
| `supabase_teacher_repository.dart` | Send grade in INSERT and RPC call |
| `classes_screen.dart` | Add grade dropdown to create + edit dialogs |
| `class_edit_screen.dart` (admin) | Add required validator to grade field |
| `teacher.dart` | `int? grade` → `int grade` |
| `teacher_class_model.dart` | Parse grade as non-nullable |

## Files NOT Changed

- `get_user_learning_paths` RPC — no change needed (root cause is fixed at data level)
- Admin panel `class_edit_screen.dart` save logic — already sends grade in data map; DB NOT NULL catches null values

## Edge Cases

- **Existing classes with null grade**: Auto-fixed in migration via name heuristic ("Test-A" → grade 5 default, "6-A" → grade 6)
- **Admin creates class without grade**: Blocked by TextFormField validator + DB NOT NULL
- **Teacher creates class without grade**: Blocked by required DropdownButtonFormField + `CreateClassParams.grade` required + DB NOT NULL
- **Teacher edits class without grade**: Blocked by required DropdownButtonFormField + `UpdateClassParams.grade` required + DB NOT NULL
- **Direct DB insert without grade**: Blocked by NOT NULL constraint
- **Admin panel bypasses RPC**: Admin uses direct `.insert()`/`.update()` — DB NOT NULL constraint is the safety net
