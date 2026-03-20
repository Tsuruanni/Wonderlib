# Special Nodes Refactor + Daily Review Gate

**Date:** 2026-03-20
**Status:** Design approved, pending implementation plan
**Depends on:** Interleaved Rendering + Lock Settings (implemented)

## Problem

Currently, three special nodes (Daily Review, Game, Treasure) are hardcoded at the end of every unit in the learning path. They cannot be configured by admins and always appear in the same position. Additionally, Daily Review has no gate behavior — students can skip it and proceed to the next item.

## Solution

### Overview

1. **Remove hardcoded special nodes** from the widget rendering loop
2. **Game + Treasure** become configurable interleaved items that admins place in templates
3. **Daily Review** becomes an automatic gate — not placed by admins, but injected by the system into the path when conditions are met, at the position just before the first locked node

### Key Design Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Game/Treasure placement | Admin-controlled via template items | Flexible positioning, consistent with interleaved system |
| Daily Review placement | Automatic, system-injected | DR is conditional (daily, 10+ words) — doesn't make sense as a fixed template item |
| DR position | Before first locked node | Natural gate point — student must do DR before progressing |
| DR persistence | Saved with position + date | Student sees past DRs when revisiting path |
| DR gate behavior | Redirect on tap ("Önce DR yap") | Non-blocking UI — student sees the path, just can't skip DR |
| Game/Treasure content | Placeholder for now | Will be configured later |

## Database Changes

### 1. Update LearningPathItemType enum

Add to `owlio_shared` enum:

```dart
enum LearningPathItemType {
  wordList('word_list', 'Word List'),
  book('book', 'Book'),
  game('game', 'Game'),
  treasure('treasure', 'Treasure');
  ...
}
```

Update CHECK constraints on `learning_path_template_items` and `scope_unit_items`:

```sql
-- Update CHECK to allow new types
ALTER TABLE learning_path_template_items
  DROP CONSTRAINT learning_path_template_items_item_type_check,
  ADD CONSTRAINT learning_path_template_items_item_type_check
    CHECK (item_type IN ('word_list', 'book', 'game', 'treasure'));

ALTER TABLE scope_unit_items
  DROP CONSTRAINT scope_unit_items_item_type_check,
  ADD CONSTRAINT scope_unit_items_item_type_check
    CHECK (item_type IN ('word_list', 'book', 'game', 'treasure'));
```

Note: For `game` and `treasure` items, both `word_list_id` and `book_id` are NULL. Update the CHECK constraint:

```sql
-- Updated CHECK for template items
ALTER TABLE learning_path_template_items
  DROP CONSTRAINT learning_path_template_items_check,
  ADD CONSTRAINT learning_path_template_items_check CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL) OR
    (item_type IN ('game', 'treasure') AND word_list_id IS NULL AND book_id IS NULL)
  );

-- Same for scope_unit_items
ALTER TABLE scope_unit_items
  DROP CONSTRAINT scope_unit_items_check,
  ADD CONSTRAINT scope_unit_items_check CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL) OR
    (item_type IN ('game', 'treasure') AND word_list_id IS NULL AND book_id IS NULL)
  );
```

### 2. Daily Review completion tracking

New table to record where and when daily reviews were completed in the path:

```sql
CREATE TABLE path_daily_review_completions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  scope_lp_unit_id UUID NOT NULL REFERENCES scope_learning_path_units(id) ON DELETE CASCADE,
  position    INTEGER NOT NULL,  -- sort_order position where DR was injected
  completed_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, scope_lp_unit_id, completed_at)  -- one DR per unit per day
);

CREATE INDEX idx_path_dr_user ON path_daily_review_completions(user_id);
CREATE INDEX idx_path_dr_unit ON path_daily_review_completions(scope_lp_unit_id);

ALTER TABLE path_daily_review_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_data" ON path_daily_review_completions
  FOR ALL USING (auth.uid() = user_id);
```

### 3. RPC for fetching DR history

```sql
CREATE OR REPLACE FUNCTION get_path_daily_reviews(p_user_id UUID)
RETURNS TABLE (
  scope_lp_unit_id UUID,
  position         INTEGER,
  completed_at     DATE
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT scope_lp_unit_id, position, completed_at
  FROM path_daily_review_completions
  WHERE user_id = p_user_id
  ORDER BY completed_at DESC;
$$;
```

## Mobile App Changes

### Entity: PathItemData hierarchy update

Add two new sealed subtypes:

```dart
class PathGameItem extends PathItemData {
  const PathGameItem({required super.sortOrder, required this.isCompleted});
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}

class PathTreasureItem extends PathItemData {
  const PathTreasureItem({required super.sortOrder, required this.isCompleted});
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}
```

### Daily Review injection in provider

The `learningPathProvider` injects DR nodes into the items list:

```dart
// After building the items list for a unit:

// 1. Fetch DR history for this unit
final drHistory = await ref.watch(pathDailyReviewsProvider.future);
final unitDrHistory = drHistory
    .where((dr) => dr.scopeLpUnitId == scopeLpUnitId)
    .toList();

// 2. Add completed DRs from history (they stay at their recorded position)
for (final dr in unitDrHistory) {
  items.add(PathDailyReviewItem(
    sortOrder: dr.position,
    completedAt: dr.completedAt,
    isCompleted: true,
  ));
}

// 3. Check if today's DR is needed (not done today + 10+ review words)
final todayDrDone = unitDrHistory.any((dr) => dr.completedAt == today);
final needsDr = !todayDrDone && reviewWordCount >= 10;

if (needsDr) {
  // Find position: just before the first locked non-exempt item
  final locks = calculateLocks(...);
  int drPosition = items.length; // default: end
  for (int i = 0; i < items.length; i++) {
    if (locks[i] && !(items[i] is PathBookItem && booksExemptFromLock)) {
      drPosition = items[i].sortOrder;
      break;
    }
  }

  items.add(PathDailyReviewItem(
    sortOrder: drPosition,
    completedAt: null,  // not completed yet
    isCompleted: false,
  ));
}

// 4. Re-sort items (DRs now interleaved at their positions)
items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
```

### Daily Review gate behavior

In the widget, when a student taps any locked-behind-DR node:

```dart
// In PathNode or PathBookNode tap handler:
if (dailyReviewPending) {
  showDialog(
    // "Bugünlük kelime tekrarını tamamlamalısın!"
    // [Daily Review'a Git] button → navigates to DR
  );
  return;
}
```

### PathDailyReviewItem entity

```dart
class PathDailyReviewItem extends PathItemData {
  const PathDailyReviewItem({
    required super.sortOrder,
    required this.completedAt,
    required this.isCompleted,
  });
  final DateTime? completedAt; // null = today's pending DR
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}
```

## Widget Changes

### Remove hardcoded special nodes

In `learning_path.dart`, remove the entire section after the items loop that renders:
- `PathDailyReviewNode`
- `PathGameNode`
- `PathTreasureNode`

These will now come through the unified items loop (Game/Treasure from template, DR from injection).

### Render new item types in the unified loop

```dart
switch (item) {
  case PathWordListItem(:final wordListWithProgress):
    // existing word list rendering
  case PathBookItem(:final bookWithProgress):
    // existing book rendering
  case PathGameItem():
    // render game node (placeholder for now)
  case PathTreasureItem():
    // render treasure node (placeholder for now)
  case PathDailyReviewItem(:final completedAt, :final isCompleted):
    // render DR node with date badge
}
```

### Unit completion update

`isAllComplete` in `PathUnitData` needs to account for new types:

```dart
bool get isAllComplete {
  final requiredItems = items.where((i) {
    if (i is PathBookItem && booksExemptFromLock) return false;
    if (i is PathDailyReviewItem) return false; // DR doesn't block unit completion
    return true;
  });
  return requiredItems.every((i) => i.isComplete);
}
```

DR completion doesn't affect unit-level progression — it's a daily gate, not a progression requirement.

## Admin Panel Changes

### Template tree-view: add Game and Treasure buttons

In `LearningPathTreeView`, add two more buttons per unit:

```
[+ Kelime Listesi Ekle]  [+ Kitap Ekle]  [+ Oyun Ekle]  [+ Hazine Ekle]
```

Game and Treasure don't need a picker dialog — they're added directly with just a type and sort_order. No `word_list_id` or `book_id`.

### Item display in tree-view

```
📝 Animals (5 kelime)       [↕] [✕]
🎮 Game                     [↕] [✕]
📖 The Cat · A1 · 4 bölüm  [↕] [✕]
🎁 Treasure                 [↕] [✕]
📝 Colors (8 kelime)        [↕] [✕]
```

## Shared Package Changes

### LearningPathItemType enum

```dart
enum LearningPathItemType {
  wordList('word_list', 'Word List'),
  book('book', 'Book'),
  game('game', 'Game'),
  treasure('treasure', 'Treasure');
  ...
}
```

### New table and RPC constants

```dart
// tables.dart
static const pathDailyReviewCompletions = 'path_daily_review_completions';

// rpc_functions.dart
static const getPathDailyReviews = 'get_path_daily_reviews';
```

## File Impact Summary

| Layer | Files | Action |
|-------|-------|--------|
| SQL Migration | 1 new | Update CHECK constraints, create DR table, add RPC |
| Shared Package | 3 files | Update enum, add table + RPC constants |
| Mobile Entity | `vocabulary_provider.dart` | Add PathGameItem, PathTreasureItem, PathDailyReviewItem to sealed hierarchy |
| Mobile Provider | `vocabulary_provider.dart` | DR injection logic, isAllComplete update |
| Mobile Widget | `learning_path.dart` | Remove hardcoded special nodes, add new cases to switch |
| Mobile Widget | `path_special_nodes.dart` | Update PathGameNode, PathTreasureNode, add PathDailyReviewNode date badge |
| Mobile Widget | `path_node.dart` | DR gate check on tap |
| Admin Widget | `learning_path_tree_view.dart` | Add Game/Treasure buttons, render new types |
| Admin Template | `template_edit_screen.dart` | Handle game/treasure item save (null FKs) |
| **Total** | ~10 files | |

## Future Work (not in this spec)

- Game node content/gameplay implementation
- Treasure node rewards implementation
- Push notifications when DR is pending
- Teacher unit control (separate spec: `project_teacher_unit_control.md`)
