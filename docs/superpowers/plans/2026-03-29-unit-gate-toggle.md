# Unit Gate Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configurable per-path toggle that controls whether units gate each other (unit N must be complete before unit N+1 unlocks).

**Architecture:** New `unit_gate` boolean column on `learning_path_templates` and `scope_learning_paths` (default `true` = current behavior). Propagated through the RPC → model → entity → provider → widget chain. Admin toggle in both template editor and assignment editor.

**Tech Stack:** PostgreSQL migration, Supabase RPC, Flutter/Dart, Riverpod

---

## File Structure

| File | Change | Description |
|------|--------|-------------|
| `supabase/migrations/20260330000001_add_unit_gate.sql` | Create | Add column + update RPC + update apply template RPC |
| `lib/domain/entities/learning_path.dart` | Modify | Add `unitGate` field to `LearningPath` |
| `lib/data/models/vocabulary/learning_path_model.dart` | Modify | Parse `unit_gate` from RPC rows |
| `lib/presentation/providers/vocabulary_provider.dart` | Modify | Pass `unitGate` through `PathUnitData`, use in `isUnitLocked` |
| `lib/presentation/widgets/learning_path/learning_path.dart` | Modify | Use `unitGate` in `isUnitLocked` calculation |
| `owlio_admin/lib/features/templates/screens/template_edit_screen.dart` | Modify | Add toggle + persist |
| `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart` | Modify | Add toggle + persist |

---

### Task 1: Database migration

**Files:**
- Create: `supabase/migrations/20260330000001_add_unit_gate.sql`

- [ ] **Step 1: Create migration file**

```sql
-- Add unit_gate column to control inter-unit locking.
-- When true (default), unit N+1 is locked until unit N is complete.
-- When false, all units are accessible regardless of completion.

-- 1. Add to templates
ALTER TABLE learning_path_templates
  ADD COLUMN unit_gate BOOLEAN NOT NULL DEFAULT true;

-- 2. Add to scope paths
ALTER TABLE scope_learning_paths
  ADD COLUMN unit_gate BOOLEAN NOT NULL DEFAULT true;

-- 3. Update apply_learning_path_template RPC to copy unit_gate
DROP FUNCTION IF EXISTS apply_learning_path_template(UUID, UUID, INTEGER, UUID, UUID);

CREATE OR REPLACE FUNCTION apply_learning_path_template(
  p_template_id UUID,
  p_school_id   UUID,
  p_grade       INTEGER DEFAULT NULL,
  p_class_id    UUID    DEFAULT NULL,
  p_user_id     UUID    DEFAULT auth.uid()
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template       RECORD;
  v_scope_lp_id    UUID;
  v_sort_order     INTEGER;
  v_template_unit  RECORD;
  v_scope_unit_id  UUID;
  v_template_item  RECORD;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = p_user_id AND role IN ('admin', 'head', 'teacher')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT name, sequential_lock, books_exempt_from_lock, unit_gate
  INTO v_template
  FROM learning_path_templates
  WHERE id = p_template_id;

  IF v_template.name IS NULL THEN
    RAISE EXCEPTION 'Template not found: %', p_template_id;
  END IF;

  SELECT COALESCE(MAX(sort_order) + 1, 0)
  INTO v_sort_order
  FROM scope_learning_paths
  WHERE school_id = p_school_id
    AND grade IS NOT DISTINCT FROM p_grade
    AND class_id IS NOT DISTINCT FROM p_class_id
  FOR UPDATE;

  INSERT INTO scope_learning_paths (
    name, template_id, school_id, grade, class_id, sort_order, created_by,
    sequential_lock, books_exempt_from_lock, unit_gate
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
    v_template.books_exempt_from_lock,
    v_template.unit_gate
  )
  RETURNING id INTO v_scope_lp_id;

  FOR v_template_unit IN
    SELECT id, unit_id, sort_order, tile_theme_id
    FROM learning_path_template_units
    WHERE template_id = p_template_id
    ORDER BY sort_order
  LOOP
    INSERT INTO scope_learning_path_units (
      scope_learning_path_id, unit_id, sort_order, tile_theme_id
    )
    VALUES (v_scope_lp_id, v_template_unit.unit_id, v_template_unit.sort_order, v_template_unit.tile_theme_id)
    RETURNING id INTO v_scope_unit_id;

    FOR v_template_item IN
      SELECT item_type, word_list_id, book_id, sort_order
      FROM learning_path_template_items
      WHERE template_unit_id = v_template_unit.id
      ORDER BY sort_order
    LOOP
      INSERT INTO scope_unit_items (
        scope_lp_unit_id, item_type, word_list_id, book_id, sort_order
      )
      VALUES (
        v_scope_unit_id,
        v_template_item.item_type,
        v_template_item.word_list_id,
        v_template_item.book_id,
        v_template_item.sort_order
      );
    END LOOP;
  END LOOP;

  RETURN v_scope_lp_id;
END;
$$;

-- 4. Update get_user_learning_paths RPC to return unit_gate
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID);

CREATE OR REPLACE FUNCTION get_user_learning_paths(p_user_id UUID)
RETURNS TABLE (
  learning_path_id        UUID,
  learning_path_name      VARCHAR,
  lp_sort_order           INTEGER,
  sequential_lock         BOOLEAN,
  books_exempt_from_lock  BOOLEAN,
  unit_gate               BOOLEAN,
  unit_id                 UUID,
  unit_name               VARCHAR,
  unit_color              VARCHAR,
  unit_icon               VARCHAR,
  unit_sort_order         INTEGER,
  tile_theme_id           UUID,
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
    slp.unit_gate,
    vu.id AS unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    slpu.tile_theme_id,
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
```

- [ ] **Step 2: Dry run**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run`

Expected: Migration listed, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260330000001_add_unit_gate.sql
git commit -m "feat: add unit_gate column and update RPCs

Adds unit_gate boolean (default true) to learning_path_templates
and scope_learning_paths. Updates apply_learning_path_template
to copy unit_gate. Updates get_user_learning_paths to return it."
```

---

### Task 2: Entity and Model

**Files:**
- Modify: `lib/domain/entities/learning_path.dart`
- Modify: `lib/data/models/vocabulary/learning_path_model.dart`

- [ ] **Step 1: Add `unitGate` to `LearningPath` entity**

In `lib/domain/entities/learning_path.dart`, update the `LearningPath` class:

```dart
class LearningPath extends Equatable {
  const LearningPath({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.units,
    this.sequentialLock = true,
    this.booksExemptFromLock = true,
    this.unitGate = true,
  });

  final String id;
  final String name;
  final int sortOrder;
  final List<LearningPathUnit> units;
  final bool sequentialLock;
  final bool booksExemptFromLock;
  final bool unitGate;

  @override
  List<Object?> get props => [id, name, sortOrder, units, sequentialLock, booksExemptFromLock, unitGate];
}
```

- [ ] **Step 2: Parse `unit_gate` in `LearningPathModel`**

In `lib/data/models/vocabulary/learning_path_model.dart`, update `_PathBuilder` and the model parsing:

In the `putIfAbsent` call (around line 14), add `unitGate`:

```dart
        () => _PathBuilder(
          id: lpId,
          name: row['learning_path_name'] as String,
          sortOrder: row['lp_sort_order'] as int,
          sequentialLock: row['sequential_lock'] as bool? ?? true,
          booksExemptFromLock: row['books_exempt_from_lock'] as bool? ?? true,
          unitGate: row['unit_gate'] as bool? ?? true,
        ),
```

In the `LearningPath` constructor call (around line 51), add:

```dart
            unitGate: pb.unitGate,
```

In the `_PathBuilder` class, add the field:

```dart
class _PathBuilder {
  _PathBuilder({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.sequentialLock,
    required this.booksExemptFromLock,
    required this.unitGate,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool sequentialLock;
  final bool booksExemptFromLock;
  final bool unitGate;
  final Map<String, _UnitBuilder> units = {};
}
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/domain/entities/learning_path.dart lib/data/models/vocabulary/learning_path_model.dart`

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/learning_path.dart lib/data/models/vocabulary/learning_path_model.dart
git commit -m "feat: add unitGate to LearningPath entity and model"
```

---

### Task 3: Provider and widget — use `unitGate` in lock calculation

**Files:**
- Modify: `lib/presentation/providers/vocabulary_provider.dart`
- Modify: `lib/presentation/widgets/learning_path/learning_path.dart`

- [ ] **Step 1: Add `unitGate` to `PathUnitData`**

In `lib/presentation/providers/vocabulary_provider.dart`, update `PathUnitData` (around line 579):

```dart
class PathUnitData {
  const PathUnitData({
    required this.unit,
    required this.items,
    required this.completedNodeTypes,
    required this.sequentialLock,
    required this.booksExemptFromLock,
    required this.unitGate,
    this.tileThemeId,
  });

  final VocabularyUnit unit;
  final List<PathItemData> items;
  final Set<String> completedNodeTypes;
  final bool sequentialLock;
  final bool booksExemptFromLock;
  final bool unitGate;
  final String? tileThemeId;
```

- [ ] **Step 2: Pass `unitGate` when building `PathUnitData`**

In `learningPathProvider` (around line 854), add `unitGate` to the constructor:

```dart
      result.add(
        PathUnitData(
          unit: vocabUnit,
          items: items,
          completedNodeTypes: nodeCompletions[lpUnit.unitId] ?? {},
          sequentialLock: path.sequentialLock,
          booksExemptFromLock: path.booksExemptFromLock,
          unitGate: path.unitGate,
          tileThemeId: lpUnit.tileThemeId,
        ),
      );
```

- [ ] **Step 3: Update `isUnitLocked` in `activeNodeYProvider`**

In `lib/presentation/providers/vocabulary_provider.dart` (around line 65), change:

Old:
```dart
    final isUnitLocked = unitIdx > 0 && !pathUnits[unitIdx - 1].isAllComplete;
```

New:
```dart
    final isUnitLocked = unit.unitGate && unitIdx > 0 && !pathUnits[unitIdx - 1].isAllComplete;
```

- [ ] **Step 4: Update `isUnitLocked` in `learning_path.dart`**

In `lib/presentation/widgets/learning_path/learning_path.dart` (line 71), change:

Old:
```dart
      final isUnitLocked = unitIdx > 0 && !units[unitIdx - 1].isAllComplete;
```

New:
```dart
      final isUnitLocked = unit.unitGate && unitIdx > 0 && !units[unitIdx - 1].isAllComplete;
```

- [ ] **Step 5: Verify**

Run: `dart analyze lib/presentation/providers/vocabulary_provider.dart lib/presentation/widgets/learning_path/learning_path.dart`

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart lib/presentation/widgets/learning_path/learning_path.dart
git commit -m "feat: use unitGate flag to control inter-unit locking

When unitGate is false, all units are accessible regardless
of previous unit completion."
```

---

### Task 4: Admin panel — template editor toggle

**Files:**
- Modify: `owlio_admin/lib/features/templates/screens/template_edit_screen.dart`

- [ ] **Step 1: Add `_unitGate` state field**

After `_booksExemptFromLock` (line 30), add:

```dart
  bool _unitGate = true;
```

- [ ] **Step 2: Load `unit_gate` from template data**

In `_loadTemplate` (after line 69 `_booksExemptFromLock = ...`), add:

```dart
      _unitGate = template['unit_gate'] as bool? ?? true;
```

- [ ] **Step 3: Save `unit_gate` in both INSERT and UPDATE**

In `_handleSave`, find the two places where `sequential_lock` and `books_exempt_from_lock` are saved (lines 220-221 and 233-234) and add `unit_gate`:

For INSERT (around line 220):
```dart
          'sequential_lock': _sequentialLock,
          'books_exempt_from_lock': _booksExemptFromLock,
          'unit_gate': _unitGate,
```

For UPDATE (around line 233):
```dart
              'sequential_lock': _sequentialLock,
              'books_exempt_from_lock': _booksExemptFromLock,
              'unit_gate': _unitGate,
```

- [ ] **Step 4: Add toggle UI**

After the `books_exempt_from_lock` SwitchListTile (after line 457), add:

```dart
            SwitchListTile(
              title: const Text('Üniteler arası kilit'),
              subtitle: const Text('Önceki ünite bitmeden sonraki açılmaz'),
              value: _unitGate,
              onChanged: (v) => setState(() => _unitGate = v),
            ),
```

- [ ] **Step 5: Verify**

Run: `dart analyze owlio_admin/lib/features/templates/screens/template_edit_screen.dart`

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add owlio_admin/lib/features/templates/screens/template_edit_screen.dart
git commit -m "feat: add unit gate toggle to template editor"
```

---

### Task 5: Admin panel — assignment editor toggle

**Files:**
- Modify: `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

- [ ] **Step 1: Add `unitGate` to `_ScopeLearningPathData`**

In the `_ScopeLearningPathData` class (around line 48), add the field:

```dart
class _ScopeLearningPathData {
  String? id;
  String name;
  String? templateId;
  int sortOrder;
  List<LearningPathUnitData> units;
  bool sequentialLock;
  bool booksExemptFromLock;
  bool unitGate;

  _ScopeLearningPathData({
    this.id,
    required this.name,
    this.templateId,
    required this.sortOrder,
    required this.units,
    this.sequentialLock = true,
    this.booksExemptFromLock = true,
    this.unitGate = true,
  });
}
```

- [ ] **Step 2: Load `unit_gate` from DB**

In `_loadScopeAssignments` (around line 218 where `_ScopeLearningPathData` is constructed), add:

```dart
        paths.add(_ScopeLearningPathData(
          id: pathId,
          name: pathRow['name'] as String? ?? '',
          templateId: pathRow['template_id'] as String?,
          sortOrder: pathRow['sort_order'] as int? ?? 0,
          units: units,
          sequentialLock: pathRow['sequential_lock'] as bool? ?? true,
          booksExemptFromLock: pathRow['books_exempt_from_lock'] as bool? ?? true,
          unitGate: pathRow['unit_gate'] as bool? ?? true,
        ));
```

Also update the SELECT query (around line 112) to include `unit_gate`:

```dart
      var query = supabase
          .from(DbTables.scopeLearningPaths)
          .select('id, name, template_id, sort_order, sequential_lock, books_exempt_from_lock, unit_gate')
          .eq('school_id', _schoolId!);
```

- [ ] **Step 3: Save `unit_gate` in `_updateLockSettings`**

In `_updateLockSettings` (around line 689), add `unit_gate`:

```dart
      await supabase
          .from(DbTables.scopeLearningPaths)
          .update({
            'sequential_lock': lp.sequentialLock,
            'books_exempt_from_lock': lp.booksExemptFromLock,
            'unit_gate': lp.unitGate,
          })
          .eq('id', lp.id!);
```

- [ ] **Step 4: Add toggle UI**

Find the `booksExemptFromLock` SwitchListTile (around line 1159) and add the unit gate toggle after it:

```dart
          SwitchListTile(
            title: const Text('Üniteler arası kilit'),
            subtitle: const Text('Önceki ünite bitmeden sonraki açılmaz'),
            value: path.unitGate,
            onChanged: (v) {
              setState(() => _learningPaths[pathIndex].unitGate = v);
              _updateLockSettings(_learningPaths[pathIndex]);
            },
          ),
```

- [ ] **Step 5: Verify**

Run: `dart analyze owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart
git commit -m "feat: add unit gate toggle to assignment editor"
```

---

### Task 6: Verify full chain

- [ ] **Step 1: Run full analyze**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`

Expected: No errors related to `unitGate` or `unit_gate`.

- [ ] **Step 2: Run admin panel analyze**

Run: `dart analyze owlio_admin/lib/`

Expected: No errors related to `unitGate` or `unit_gate`.

- [ ] **Step 3: Manual test — admin**

1. Open admin panel → Öğrenme Yolları → Şablonlar → edit a template
2. Verify "Üniteler arası kilit" toggle is visible below "Sıralı ilerleme"
3. Toggle it off, save — reload, verify it persisted
4. Go to Atamalar → edit an assignment
5. Verify "Üniteler arası kilit" toggle is visible
6. Toggle it off — verify snackbar "Kilit ayarları güncellendi"
7. Reload — verify it persisted

- [ ] **Step 4: Manual test — student**

1. Log in as student (active@demo.com / Test1234)
2. Open vocabulary hub — verify learning path renders
3. If the assignment has `unit_gate = false`, verify all units are accessible (no lock icons on unit dividers)
4. If `unit_gate = true`, verify previous behavior (units locked until prior complete)
