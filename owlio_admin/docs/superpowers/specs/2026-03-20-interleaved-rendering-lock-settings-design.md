# Interleaved Rendering + Template Lock Settings

**Date:** 2026-03-20
**Status:** Design approved, pending implementation plan
**Depends on:** Learning Path Templates system (implemented)

## Problem

The mobile learning path widget renders all word lists first, then all books — ignoring the `sort_order` from the database. Items should render in the exact order defined in the template/scope (interleaved). Additionally, there is no way to configure lock behavior (sequential progression, book exemption) per template.

## Solution

### Overview

1. **Interleaved rendering**: Merge the separate `rows` (word lists) and `books` lists in `PathUnitData` into a single `items` list ordered by `sort_order`. Update the widget to render from this unified list.

2. **Template lock settings**: Add two boolean settings to templates (and their scope copies):
   - `sequential_lock`: items are locked until the previous item is completed
   - `books_exempt_from_lock`: books are always accessible regardless of progression

### Key Design Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Lock settings scope | Template-level (not per-unit) | Simpler, sufficient for current needs |
| Default values | `sequential_lock=true`, `books_exempt_from_lock=true` | Matches current behavior expectations |
| Book lock exemption | Books skip the lock chain entirely | Books are supplementary reading, not gates |
| Settings storage | Both template and scope tables | Scope copies settings at apply time (snapshot model) |
| Unit completion for next-unit unlock | Only non-exempt items count | If books are exempt from lock, they don't need to be completed for the next unit to unlock |
| Lock settings mutability per scope | Editable | Admin can change lock settings per scope after applying template |

## Database Changes

### Migration: Add lock settings columns

```sql
-- Template table
ALTER TABLE learning_path_templates
  ADD COLUMN sequential_lock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN books_exempt_from_lock BOOLEAN NOT NULL DEFAULT true;

-- Scope table (snapshot copy)
ALTER TABLE scope_learning_paths
  ADD COLUMN sequential_lock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN books_exempt_from_lock BOOLEAN NOT NULL DEFAULT true;
```

### Migration: Update apply_learning_path_template RPC

**IMPORTANT:** PostgreSQL requires `DROP FUNCTION` before `CREATE OR REPLACE` when the return type changes. Both RPCs must be dropped first.

```sql
-- Drop existing functions (return type is changing)
DROP FUNCTION IF EXISTS apply_learning_path_template(UUID, UUID, INTEGER, UUID, UUID);
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID);

-- Recreate apply_learning_path_template with lock settings copy
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
BEGIN
  -- Get template info (including lock settings)
  SELECT name, sequential_lock, books_exempt_from_lock
  INTO v_template
  FROM learning_path_templates
  WHERE id = p_template_id;

  IF v_template.name IS NULL THEN
    RAISE EXCEPTION 'Template not found: %', p_template_id;
  END IF;

  -- Create scope learning path (with lock settings copied from template)
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
    COALESCE(
      (SELECT MAX(sort_order) + 1 FROM scope_learning_paths
       WHERE school_id = p_school_id
         AND grade IS NOT DISTINCT FROM p_grade
         AND class_id IS NOT DISTINCT FROM p_class_id),
      0
    ),
    p_user_id,
    v_template.sequential_lock,
    v_template.books_exempt_from_lock
  )
  RETURNING id INTO v_scope_lp_id;

  -- Copy template units
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
```

### Migration: Update get_user_learning_paths RPC

```sql
-- Recreate with two new columns in return type
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
```

## Mobile App Changes

### Entity: LearningPath

Add two fields:

```dart
class LearningPath extends Equatable {
  final String id;
  final String name;
  final int sortOrder;
  final bool sequentialLock;
  final bool booksExemptFromLock;
  final List<LearningPathUnit> units;
  ...
}
```

### Model: LearningPathModel

Parse the two new fields from RPC rows:

```dart
final pathBuilder = pathMap.putIfAbsent(lpId, () => _PathBuilder(
  ...
  sequentialLock: row['sequential_lock'] as bool? ?? true,
  booksExemptFromLock: row['books_exempt_from_lock'] as bool? ?? true,
));
```

### Provider: PathUnitData refactor

Replace separate `rows` + `books` with a single unified `items` list:

```dart
// OLD (broken):
class PathUnitData {
  final VocabularyUnit unit;
  final List<PathRowData> rows;           // only word lists
  final List<UnitBookWithProgress> books; // only books
  final Set<String> completedNodeTypes;
}

// NEW (interleaved):
class PathUnitData {
  final VocabularyUnit unit;
  final List<PathItemData> items;         // ALL items, interleaved by sort_order
  final Set<String> completedNodeTypes;
  final bool sequentialLock;
  final bool booksExemptFromLock;

  /// Whether this unit is "complete" for the purpose of unlocking the next unit.
  /// Only non-exempt items count. If booksExemptFromLock is true, books are excluded.
  /// Note: if all items are exempt (unit with only books + exempt=true),
  /// .every() on empty iterable returns true → unit is considered complete.
  bool get isAllComplete {
    final requiredItems = items.where((i) =>
        !(i.type == LearningPathItemType.book && booksExemptFromLock));
    final specialComplete = completedNodeTypes.containsAll(
        {'daily_review', 'game', 'treasure'});
    return requiredItems.every((i) => i.isComplete) && specialComplete;
  }
}

/// Sealed class for type-safe item representation
sealed class PathItemData {
  final int sortOrder;
  const PathItemData({required this.sortOrder});
  bool get isComplete;
}

class PathWordListItem extends PathItemData {
  final WordListWithProgress wordListWithProgress;
  const PathWordListItem({
    required super.sortOrder,
    required this.wordListWithProgress,
  });

  @override
  bool get isComplete => wordListWithProgress.isComplete;
}

class PathBookItem extends PathItemData {
  final UnitBookWithProgress bookWithProgress;
  const PathBookItem({
    required super.sortOrder,
    required this.bookWithProgress,
  });

  @override
  bool get isComplete => bookWithProgress.isCompleted;
}
```

The `learningPathProvider` builds a single `items` list from `lpUnit.items` in sort_order, creating either `PathWordListItem` or `PathBookItem` based on `item.itemType`.

### Provider: Lock calculation

```dart
List<bool> calculateLocks({
  required List<PathItemData> items,
  required bool sequentialLock,
  required bool booksExemptFromLock,
  required bool isUnitLocked,
}) {
  // Entire unit locked
  if (isUnitLocked) {
    return List.filled(items.length, true);
  }

  // No sequential lock — all items open
  if (!sequentialLock) {
    return List.filled(items.length, false);
  }

  // Sequential lock with optional book exemption
  final locks = List.filled(items.length, false);
  bool previousNonExemptCompleted = true; // first non-exempt item is always open

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final isBook = item is PathBookItem;

    if (isBook && booksExemptFromLock) {
      locks[i] = false; // books always open when exempt
      // Don't update previousNonExemptCompleted — books don't count in the chain
    } else {
      locks[i] = !previousNonExemptCompleted;
      if (!locks[i]) {
        // This item is unlocked; update chain based on its completion
        previousNonExemptCompleted = item.isComplete;
      }
      // If locked, previousNonExemptCompleted stays false → all subsequent locked too
    }
  }

  return locks;
}
```

### Widget: learning_path.dart

Replace the two-loop rendering (rows loop at lines 104-173 + books loop at lines 186-225) with a single loop over `unit.items`:

```
// Pre-calculate locks for all items in this unit
final locks = calculateLocks(
  items: unit.items,
  sequentialLock: unit.sequentialLock,
  booksExemptFromLock: unit.booksExemptFromLock,
  isUnitLocked: isUnitLocked,
);

for (int itemIdx = 0; itemIdx < unit.items.length; itemIdx++) {
  final item = unit.items[itemIdx];
  final isLocked = locks[itemIdx];

  // Zigzag positioning (same math as current PathRow)
  final centerXs = _nodeCenterXs(globalRowIndex, screenWidth);

  // Active detection: first unlocked + incomplete
  bool isActive = false;
  if (!foundActive && !isLocked && !item.isComplete) {
    isActive = true;
    foundActive = true;
  }

  // Render based on type
  switch (item) {
    case PathWordListItem(:final wordListWithProgress):
      // Render PathNode (existing word list node widget)
    case PathBookItem(:final bookWithProgress):
      // Render PathBookNode (existing book node widget)
  }

  // Connector to next node (same logic as current)
}
```

### Widget: PathRow refactor

`PathRow` currently wraps a `PathNode` with zigzag positioning. After the refactor, both word list nodes and book nodes need the same zigzag positioning. Two approaches:

**Recommended:** Keep `PathRow` but make it accept any child widget (not just `PathNode`). It becomes a generic positioning wrapper:

```dart
class PathRow extends StatelessWidget {
  final int globalRowIndex;
  final double screenWidth;
  final Widget child;  // PathNode or PathBookNode
  ...
}
```

This eliminates the duplicate positioning logic currently in `path_special_nodes.dart`.

### Widget: Special nodes after items

After all items are rendered, the existing special nodes (Daily Review, Game, Treasure) remain. Their lock condition uses the new `isAllComplete`:

```dart
// allItemsDone considers book exemption
final allItemsDone = unit.items
    .where((i) => !(i is PathBookItem && unit.booksExemptFromLock))
    .every((i) => i.isComplete);
```

### Removed types

- `PathRowData` — replaced by sealed `PathItemData` hierarchy
- `isAllListsComplete`, `isAllBooksComplete` getters — replaced by `isAllComplete`

## Admin Panel Changes

### Template Edit Screen

Add "İlerleme Ayarları" section below template name/description:

```
İlerleme Ayarları
  ☑ Sıralı ilerleme (önceki tamamlanmadan sonraki açılmaz)
  ☑ Kitapları hariç tut (kitaplar her zaman erişilebilir)
```

"Kitapları hariç tut" is only visible/enabled when "Sıralı ilerleme" is checked.

State:
```dart
bool _sequentialLock = true;
bool _booksExemptFromLock = true;
```

Load: Read `sequential_lock` and `books_exempt_from_lock` from template row (already included in `select('*')` at line 61).

Save: Include both fields in template INSERT and UPDATE operations.

### Assignment Screen

Lock settings are **editable per scope** — admin can override the template's defaults after applying.

Load: Read `sequential_lock` and `books_exempt_from_lock` from `scope_learning_paths` row.

Display: Show two toggles in each learning path's header card (similar to template screen).

Save: When saving scope changes (the delete-all + re-insert pattern), UPDATE the `scope_learning_paths` row to persist lock setting changes.

## File Impact Summary

| Layer | Files | Action |
|-------|-------|--------|
| SQL Migration | 1 new | Add columns, DROP + CREATE both RPCs |
| Mobile Entity | `learning_path.dart` | Add 2 fields |
| Mobile Model | `learning_path_model.dart` | Parse 2 new fields |
| Mobile Provider | `vocabulary_provider.dart` | Refactor PathUnitData to sealed PathItemData, unified items, lock calculation, isAllComplete |
| Mobile Widget | `learning_path.dart` | Single-loop interleaved render with lock array |
| Mobile Widget | `path_special_nodes.dart` | Update lock conditions, remove duplicate positioning |
| Mobile Widget | `path_row.dart` | Generalize to accept any child (not just PathNode) |
| Mobile Widget | `path_node.dart` | Accept PathWordListItem instead of WordListWithProgress |
| Admin Template Screen | `template_edit_screen.dart` | 2 toggles, load/save |
| Admin Assignment Screen | `assignment_screen.dart` | 2 toggles per learning path, load/save/update |
| **Total** | ~10 files | |
