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

The RPC must copy the two new columns when applying a template to a scope:

```sql
CREATE OR REPLACE FUNCTION apply_learning_path_template(...)
-- In the INSERT INTO scope_learning_paths statement, add:
--   sequential_lock = (SELECT sequential_lock FROM learning_path_templates WHERE id = p_template_id),
--   books_exempt_from_lock = (SELECT books_exempt_from_lock FROM learning_path_templates WHERE id = p_template_id)
```

### Migration: Update get_user_learning_paths RPC

Add two new columns to the return type:

```sql
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
```

The SELECT adds `slp.sequential_lock` and `slp.books_exempt_from_lock` from `scope_learning_paths`.

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
}

class PathItemData {
  final LearningPathItemType type;   // word_list or book
  final int sortOrder;
  // For word_list:
  final WordListWithProgress? wordListWithProgress;
  // For book:
  final UnitBookWithProgress? bookWithProgress;

  bool get isComplete {
    if (type == LearningPathItemType.wordList) {
      return wordListWithProgress?.isComplete ?? false;
    } else {
      return bookWithProgress?.isCompleted ?? false;
    }
  }
}
```

The `learningPathProvider` builds a single `items` list from `lpUnit.items` in sort_order, populating either `wordListWithProgress` or `bookWithProgress` based on `item.itemType`.

### Provider: Lock calculation

```dart
// In learningPathProvider or as a helper:
List<bool> calculateLocks(List<PathItemData> items, bool sequentialLock, bool booksExemptFromLock, bool isUnitLocked) {
  final locks = List.filled(items.length, false);

  if (isUnitLocked) {
    // Entire unit locked
    return List.filled(items.length, true);
  }

  if (!sequentialLock) {
    // No sequential lock — all items open
    return locks;
  }

  // Sequential lock with optional book exemption
  bool previousNonExemptCompleted = true; // first item is always open

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final isBook = item.type == LearningPathItemType.book;

    if (isBook && booksExemptFromLock) {
      locks[i] = false; // books always open
      // Don't update previousNonExemptCompleted — books don't count
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

### Widget: learning_path.dart

Replace the two-loop rendering (rows loop + books loop) with a single loop over `unit.items`:

```
for each item in unit.items:
  if item.type == word_list:
    render PathNode (word list node)
  else if item.type == book:
    render PathBookNode (book node)

  apply lock state from calculateLocks()
  apply active state (first unlocked + incomplete)
  render connector between nodes
```

The zigzag pattern, connector drawing, and active detection logic stay the same — they just iterate over a unified list instead of two separate lists.

### Widget: Special nodes after items

After all items are rendered, the existing special nodes (Daily Review, Game, Treasure) remain. Their lock condition changes from `allBooksDone` to `allItemsComplete` (all non-exempt items in the unit are done).

```dart
final allItemsDone = unit.items
    .where((i) => !(i.type == LearningPathItemType.book && unit.booksExemptFromLock))
    .every((i) => i.isComplete);
```

### Removed types

- `PathRowData` — replaced by `PathItemData`
- `UnitBookWithProgress.sortOrder` field — now in `PathItemData.sortOrder`

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

Save: include in template INSERT/UPDATE.
Load: read from template row.

### Assignment Screen

When loading scope learning paths, read `sequential_lock` and `books_exempt_from_lock` from `scope_learning_paths`. Display as read-only or editable toggles in the learning path header.

When saving scope changes, persist these values.

## File Impact Summary

| Layer | Files | Action |
|-------|-------|--------|
| SQL Migration | 1 new | Add columns + update 2 RPCs |
| Mobile Entity | `learning_path.dart` | Add 2 fields |
| Mobile Model | `learning_path_model.dart` | Parse 2 new fields |
| Mobile Provider | `vocabulary_provider.dart` | Refactor PathUnitData, unified items list, lock calculation |
| Mobile Widget | `learning_path.dart` | Single-loop interleaved render |
| Mobile Widget | `path_special_nodes.dart` | Update lock conditions |
| Mobile Widget | `path_row.dart` | May need updates or removal |
| Mobile Widget | `path_node.dart` | Update to work with PathItemData |
| Admin Template Screen | `template_edit_screen.dart` | 2 toggles |
| Admin Assignment Screen | `assignment_screen.dart` | Read/display lock settings |
| **Total** | ~10 files | |
