# Interleaved Rendering + Lock Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the mobile learning path to render items in template-defined order (interleaved word lists + books) and add configurable sequential lock with book exemption.

**Architecture:** Add lock setting columns to DB, update RPCs, refactor PathUnitData from separate rows+books to a unified sealed PathItemData list, rewrite the learning_path widget's rendering loop, and add toggle UI to admin template/assignment screens.

**Tech Stack:** PostgreSQL 17 (Supabase), Flutter, Riverpod, owlio_shared

**Spec:** `docs/superpowers/specs/2026-03-20-interleaved-rendering-lock-settings-design.md`

---

## Phase 1: Database

### Task 1: Add lock settings columns and update RPCs

**Files:**
- Create: `supabase/migrations/20260320000004_add_lock_settings_and_update_rpcs.sql`

- [ ] **Step 1: Write the migration**

```sql
-- =============================================
-- ADD LOCK SETTINGS + UPDATE RPCS
-- =============================================

-- 1. Add lock columns to template table
ALTER TABLE learning_path_templates
  ADD COLUMN sequential_lock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN books_exempt_from_lock BOOLEAN NOT NULL DEFAULT true;

-- 2. Add lock columns to scope table
ALTER TABLE scope_learning_paths
  ADD COLUMN sequential_lock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN books_exempt_from_lock BOOLEAN NOT NULL DEFAULT true;

-- 3. Drop existing RPCs (return type changing requires drop first)
DROP FUNCTION IF EXISTS apply_learning_path_template(UUID, UUID, INTEGER, UUID, UUID);
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID);

-- 4. Recreate apply_learning_path_template with lock settings
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
  SELECT name, sequential_lock, books_exempt_from_lock
  INTO v_template
  FROM learning_path_templates
  WHERE id = p_template_id;

  IF v_template.name IS NULL THEN
    RAISE EXCEPTION 'Template not found: %', p_template_id;
  END IF;

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

-- 5. Recreate get_user_learning_paths with lock columns
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

- [ ] **Step 2: Preview and push**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run` then `supabase db push`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260320000004_add_lock_settings_and_update_rpcs.sql
git commit -m "feat(db): add lock settings columns and update RPCs"
```

---

## Phase 2: Mobile Entity + Model

### Task 2: Update LearningPath entity and model

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/domain/entities/learning_path.dart`
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/data/models/vocabulary/learning_path_model.dart`

- [ ] **Step 1: Add lock fields to LearningPath entity**

In `learning_path.dart`, add two fields to `LearningPath`:

```dart
final bool sequentialLock;
final bool booksExemptFromLock;
```

Add to constructor (with defaults), and to `props` list.

- [ ] **Step 2: Update LearningPathModel parser**

In `learning_path_model.dart`, update `_PathBuilder` to include the two new fields. Parse from RPC row:

```dart
sequentialLock: row['sequential_lock'] as bool? ?? true,
booksExemptFromLock: row['books_exempt_from_lock'] as bool? ?? true,
```

Pass them through to the `LearningPath` entity construction.

- [ ] **Step 3: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/domain/entities/learning_path.dart lib/data/models/vocabulary/learning_path_model.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/learning_path.dart lib/data/models/vocabulary/learning_path_model.dart
git commit -m "feat: add lock settings to LearningPath entity and model"
```

---

## Phase 3: Provider Refactor

### Task 3: Refactor PathUnitData to unified items list

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/providers/vocabulary_provider.dart`

This is the most critical task. Read the entire file first (especially `PathUnitData`, `PathRowData`, `WordListWithProgress`, `UnitBookWithProgress`, `learningPathProvider`, and `isAllComplete`/`isAllListsComplete`/`isAllBooksComplete` getters).

- [ ] **Step 1: Create sealed PathItemData hierarchy**

Replace `PathRowData` with:

```dart
sealed class PathItemData {
  const PathItemData({required this.sortOrder});
  final int sortOrder;
  bool get isComplete;
}

class PathWordListItem extends PathItemData {
  const PathWordListItem({
    required super.sortOrder,
    required this.wordListWithProgress,
  });
  final WordListWithProgress wordListWithProgress;

  @override
  bool get isComplete => wordListWithProgress.isComplete;
}

class PathBookItem extends PathItemData {
  const PathBookItem({
    required super.sortOrder,
    required this.bookWithProgress,
  });
  final UnitBookWithProgress bookWithProgress;

  @override
  bool get isComplete => bookWithProgress.isCompleted;
}
```

- [ ] **Step 2: Update PathUnitData**

Replace `rows` + `books` with unified `items`:

```dart
class PathUnitData {
  const PathUnitData({
    required this.unit,
    required this.items,
    required this.completedNodeTypes,
    required this.sequentialLock,
    required this.booksExemptFromLock,
  });
  final VocabularyUnit unit;
  final List<PathItemData> items;
  final Set<String> completedNodeTypes;
  final bool sequentialLock;
  final bool booksExemptFromLock;

  bool get isAllComplete {
    final requiredItems = items.where((i) =>
        !(i is PathBookItem && booksExemptFromLock));
    final specialComplete = completedNodeTypes.containsAll(
        const {'daily_review', 'game', 'treasure'});
    return requiredItems.every((i) => i.isComplete) && specialComplete;
  }
}
```

Remove `isAllListsComplete`, `isAllBooksComplete` getters. Remove `PathRowData` class.

- [ ] **Step 3: Add calculateLocks helper**

```dart
List<bool> calculateLocks({
  required List<PathItemData> items,
  required bool sequentialLock,
  required bool booksExemptFromLock,
  required bool isUnitLocked,
}) {
  if (isUnitLocked) return List.filled(items.length, true);
  if (!sequentialLock) return List.filled(items.length, false);

  final locks = List.filled(items.length, false);
  bool previousNonExemptCompleted = true;

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final isExemptBook = item is PathBookItem && booksExemptFromLock;

    if (isExemptBook) {
      locks[i] = false;
    } else {
      locks[i] = !previousNonExemptCompleted;
      if (!locks[i]) {
        previousNonExemptCompleted = item.isComplete;
      }
    }
  }
  return locks;
}
```

- [ ] **Step 4: Rewrite learningPathProvider**

The provider should build a single `items` list per unit instead of separate `rows` and `books`:

```dart
// For each item in lpUnit.items (already sorted by sortOrder):
final items = <PathItemData>[];
for (final item in lpUnit.items) {
  if (item.itemType == LearningPathItemType.wordList) {
    final wordList = wordListMap[item.itemId];
    if (wordList == null) continue;
    items.add(PathWordListItem(
      sortOrder: item.sortOrder,
      wordListWithProgress: WordListWithProgress(
        wordList: wordList,
        progress: progressMap[item.itemId],
      ),
    ));
  } else if (item.itemType == LearningPathItemType.book) {
    final book = await ref.watch(bookByIdProvider(item.itemId).future);
    if (book != null) {
      items.add(PathBookItem(
        sortOrder: item.sortOrder,
        bookWithProgress: UnitBookWithProgress(
          bookId: item.itemId,
          book: book,
          isCompleted: completedBookIds.contains(item.itemId),
          sortOrder: item.sortOrder,
        ),
      ));
    }
  }
}

// Sort by sortOrder (should already be sorted from RPC, but explicit is safe)
items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

result.add(PathUnitData(
  unit: vocabUnit,
  items: items,
  completedNodeTypes: nodeCompletions[lpUnit.unitId] ?? {},
  sequentialLock: path.sequentialLock,
  booksExemptFromLock: path.booksExemptFromLock,
));
```

- [ ] **Step 5: Verify provider compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/vocabulary_provider.dart`

There WILL be errors in widget files (they still reference `unit.rows`, `unit.books`) — that's Task 4.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/providers/vocabulary_provider.dart
git commit -m "feat: refactor PathUnitData to unified sealed PathItemData list with lock calculation"
```

---

## Phase 4: Widget Refactor

### Task 4: Rewrite learning_path.dart for interleaved rendering

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/widgets/vocabulary/learning_path.dart`
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/widgets/vocabulary/path_row.dart`
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/widgets/vocabulary/path_special_nodes.dart`
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/widgets/vocabulary/path_node.dart`

Read ALL four files thoroughly before making changes. Understand the zigzag positioning math, connector drawing, active detection, and how PathNode/PathBookNode render.

- [ ] **Step 1: Generalize PathRow to accept any child**

Currently `PathRow` takes `PathRowData` and renders `PathNode`. Change it to accept a generic `Widget child` (or `PathItemData`) and handle both word list and book rendering:

```dart
class PathRow extends StatelessWidget {
  final int globalRowIndex;
  final double screenWidth;
  final bool isLocked;
  final bool isActive;
  final bool canStartNewList;
  final Widget child;  // PathNode or PathBookNode
  ...
}
```

- [ ] **Step 2: Replace two-loop rendering with single loop**

In `learning_path.dart`, the `_buildPath` method currently has:
- Lines 104-173: loop over `unit.rows` (word lists)
- Lines 186-225: loop over `unit.books` (books)

Replace BOTH loops with a single loop over `unit.items`:

```dart
// Pre-calculate locks
final locks = calculateLocks(
  items: unit.items,
  sequentialLock: unit.sequentialLock,
  booksExemptFromLock: unit.booksExemptFromLock,
  isUnitLocked: isUnitLocked,
);

for (int itemIdx = 0; itemIdx < unit.items.length; itemIdx++) {
  final item = unit.items[itemIdx];
  final isItemLocked = locks[itemIdx];

  // Active detection
  bool isActive = false;
  if (!foundActive && !isItemLocked && !item.isComplete) {
    isActive = true;
    foundActive = true;
  }

  // Zigzag positioning
  final currentNodeCenterXs = _nodeCenterXs(
    globalRowIndex: globalRowIndex,
    screenWidth: screenWidth,
  );

  // Connector
  // ... (same connector logic as current, using prevNodeCenterXs)

  // Render based on type
  switch (item) {
    case PathWordListItem(:final wordListWithProgress):
      // Render using PathNode (same as current row rendering)
      nodes.add(Positioned(
        top: y,
        left: 0, right: 0,
        child: PathRow(
          globalRowIndex: globalRowIndex,
          screenWidth: screenWidth,
          child: PathNode(
            wordListWithProgress: wordListWithProgress,
            isLocked: isItemLocked,
            isActive: isActive,
            canStartNewList: canStartNewList,
          ),
        ),
      ));

    case PathBookItem(:final bookWithProgress):
      // Render using PathBookNode (same positioning as word list now)
      nodes.add(Positioned(
        top: y,
        left: 0, right: 0,
        child: PathRow(
          globalRowIndex: globalRowIndex,
          screenWidth: screenWidth,
          child: PathBookNode(
            globalRowIndex: globalRowIndex,
            bookTitle: bookWithProgress.book.title,
            bookId: bookWithProgress.book.id,
            isLocked: isItemLocked,
            isComplete: bookWithProgress.isCompleted,
            isActive: isActive,
          ),
        ),
      ));
  }

  y += 80.0;
  prevNodeCenterXs = currentNodeCenterXs;
  globalRowIndex++;
}
```

- [ ] **Step 3: Update special nodes lock conditions**

After the items loop, update the lock conditions for Daily Review, Game, Treasure:

```dart
// Replace allListsDone / allBooksDone with:
final allRequiredDone = unit.items
    .where((i) => !(i is PathBookItem && unit.booksExemptFromLock))
    .every((i) => i.isComplete);

// Use allRequiredDone instead of allListsDone/allBooksDone for:
// - Daily Review lock
// - Connector coloring before Daily Review
```

- [ ] **Step 4: Update path_node.dart if needed**

Check if `PathNode` takes `WordListWithProgress` directly or via `PathRowData`. If via `PathRowData`, update to accept `WordListWithProgress` directly.

- [ ] **Step 5: Clean up path_special_nodes.dart**

Remove duplicate zigzag positioning logic from `PathBookNode` (the `_rowLeftEdge`, `_sineOffset` helpers) since book nodes now go through `PathRow` for positioning.

- [ ] **Step 6: Full compilation check**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: 0 errors

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/widgets/vocabulary/ lib/presentation/providers/
git commit -m "feat: interleaved learning path rendering with unified item loop"
```

---

## Phase 5: Admin Panel

### Task 5: Add lock settings to template edit screen

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/templates/screens/template_edit_screen.dart`

- [ ] **Step 1: Add state variables**

```dart
bool _sequentialLock = true;
bool _booksExemptFromLock = true;
```

- [ ] **Step 2: Load lock settings in _loadTemplate**

The existing `select('*')` on the template row already includes the new columns. Add to the load logic:

```dart
_sequentialLock = template['sequential_lock'] as bool? ?? true;
_booksExemptFromLock = template['books_exempt_from_lock'] as bool? ?? true;
```

- [ ] **Step 3: Save lock settings in _handleSave**

Add to both INSERT (new template) and UPDATE (existing template):

```dart
'sequential_lock': _sequentialLock,
'books_exempt_from_lock': _booksExemptFromLock,
```

- [ ] **Step 4: Add UI toggles**

Below the description field, before the content section, add:

```dart
const SizedBox(height: 24),
Text('İlerleme Ayarları', style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 8),
SwitchListTile(
  title: const Text('Sıralı ilerleme'),
  subtitle: const Text('Önceki tamamlanmadan sonraki açılmaz'),
  value: _sequentialLock,
  onChanged: (v) => setState(() {
    _sequentialLock = v;
    if (!v) _booksExemptFromLock = true;
  }),
),
if (_sequentialLock)
  SwitchListTile(
    title: const Text('Kitapları hariç tut'),
    subtitle: const Text('Kitaplar her zaman erişilebilir'),
    value: _booksExemptFromLock,
    onChanged: (v) => setState(() => _booksExemptFromLock = v),
  ),
```

- [ ] **Step 5: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/templates/`

- [ ] **Step 6: Commit**

```bash
git add owlio_admin/lib/features/templates/
git commit -m "feat(admin): add lock settings toggles to template edit screen"
```

---

### Task 6: Add lock settings to assignment screen

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

- [ ] **Step 1: Add lock fields to _ScopeLearningPathData**

```dart
class _ScopeLearningPathData {
  ...
  bool sequentialLock;
  bool booksExemptFromLock;
}
```

- [ ] **Step 2: Load lock settings when loading scope assignments**

When fetching `scope_learning_paths`, include `sequential_lock` and `books_exempt_from_lock` in the select. Map to `_ScopeLearningPathData`.

- [ ] **Step 3: Add toggles per learning path**

In each learning path's card header, add two toggle switches (same pattern as template screen).

- [ ] **Step 4: Save lock settings on change**

When lock settings change, UPDATE the `scope_learning_paths` row:

```dart
await supabase
    .from(DbTables.scopeLearningPaths)
    .update({
      'sequential_lock': lp.sequentialLock,
      'books_exempt_from_lock': lp.booksExemptFromLock,
    })
    .eq('id', lp.id!);
```

- [ ] **Step 5: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/features/learning_path_assignments/`

- [ ] **Step 6: Commit**

```bash
git add owlio_admin/lib/features/learning_path_assignments/
git commit -m "feat(admin): add lock settings to assignment screen"
```

---

## Execution Order

```
Task 1 (DB) → Task 2 (Entity/Model) → Task 3 (Provider) → Task 4 (Widgets) → Task 5 + 6 (Admin, parallel)
```

**Total: 6 tasks, ~10 files**
