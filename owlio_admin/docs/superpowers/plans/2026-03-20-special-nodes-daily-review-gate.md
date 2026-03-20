# Special Nodes + Daily Review Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove hardcoded special nodes from the learning path, make Game/Treasure configurable template items, and implement Daily Review as an automatic gate injected into the path.

**Architecture:** Update DB CHECK constraints for new item types, create DR completion tracking table, extend sealed PathItemData hierarchy with 3 new subtypes, inject DR nodes in the provider, render all types in the unified widget loop.

**Tech Stack:** PostgreSQL 17 (Supabase), Flutter, Riverpod, owlio_shared

**Spec:** `docs/superpowers/specs/2026-03-20-special-nodes-and-daily-review-gate-design.md`

---

## Phase 1: Database + Shared Package

### Task 1: Update DB constraints and create DR table

**Files:**
- Create: `supabase/migrations/20260320000005_special_nodes_and_dr_table.sql`

- [ ] **Step 1: Write the migration**

```sql
-- =============================================
-- SPECIAL NODES + DAILY REVIEW GATE
-- =============================================

-- 1. Update CHECK constraints to allow game/treasure item types
-- Template items
ALTER TABLE learning_path_template_items
  DROP CONSTRAINT IF EXISTS learning_path_template_items_item_type_check;
ALTER TABLE learning_path_template_items
  ADD CONSTRAINT learning_path_template_items_item_type_check
    CHECK (item_type IN ('word_list', 'book', 'game', 'treasure'));

ALTER TABLE learning_path_template_items
  DROP CONSTRAINT IF EXISTS learning_path_template_items_check;
ALTER TABLE learning_path_template_items
  ADD CONSTRAINT learning_path_template_items_check CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL) OR
    (item_type IN ('game', 'treasure') AND word_list_id IS NULL AND book_id IS NULL)
  );

-- Scope items
ALTER TABLE scope_unit_items
  DROP CONSTRAINT IF EXISTS scope_unit_items_item_type_check;
ALTER TABLE scope_unit_items
  ADD CONSTRAINT scope_unit_items_item_type_check
    CHECK (item_type IN ('word_list', 'book', 'game', 'treasure'));

ALTER TABLE scope_unit_items
  DROP CONSTRAINT IF EXISTS scope_unit_items_check;
ALTER TABLE scope_unit_items
  ADD CONSTRAINT scope_unit_items_check CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL) OR
    (item_type IN ('game', 'treasure') AND word_list_id IS NULL AND book_id IS NULL)
  );

-- 2. Daily Review completion tracking
CREATE TABLE path_daily_review_completions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  scope_lp_unit_id UUID NOT NULL REFERENCES scope_learning_path_units(id) ON DELETE CASCADE,
  position         INTEGER NOT NULL,
  completed_at     DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, scope_lp_unit_id, completed_at)
);

CREATE INDEX idx_path_dr_user ON path_daily_review_completions(user_id);
CREATE INDEX idx_path_dr_unit ON path_daily_review_completions(scope_lp_unit_id);

ALTER TABLE path_daily_review_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_data" ON path_daily_review_completions
  FOR ALL USING (auth.uid() = user_id);

-- 3. RPC for fetching DR history
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

- [ ] **Step 2: Preview and push**

Run: `cd /Users/wonderelt/Desktop/Owlio && supabase db push --dry-run` then `supabase db push`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260320000005_special_nodes_and_dr_table.sql
git commit -m "feat(db): update item type constraints, add DR completion table and RPC"
```

---

### Task 2: Update shared package

**Files:**
- Modify: `packages/owlio_shared/lib/src/enums/learning_path_item_type.dart`
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Add game and treasure to LearningPathItemType enum**

```dart
enum LearningPathItemType {
  wordList('word_list', 'Word List'),
  book('book', 'Book'),
  game('game', 'Game'),
  treasure('treasure', 'Treasure');
  ...
}
```

- [ ] **Step 2: Add new constants**

In `tables.dart`:
```dart
static const pathDailyReviewCompletions = 'path_daily_review_completions';
```

In `rpc_functions.dart`:
```dart
static const getPathDailyReviews = 'get_path_daily_reviews';
```

- [ ] **Step 3: Verify all projects compile**

```bash
cd /Users/wonderelt/Desktop/Owlio/packages/owlio_shared && dart analyze
cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/
cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/
```

- [ ] **Step 4: Commit**

```bash
git add packages/owlio_shared/
git commit -m "feat(shared): add game/treasure to LearningPathItemType, add DR constants"
```

---

## Phase 2: Mobile Provider + Entity

### Task 3: Extend sealed PathItemData and update provider

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/providers/vocabulary_provider.dart`

- [ ] **Step 1: Read the current file**

Read the entire `vocabulary_provider.dart` to understand the current sealed hierarchy and `learningPathProvider`.

- [ ] **Step 2: Add three new sealed subtypes**

After `PathBookItem`, add:

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

class PathDailyReviewItem extends PathItemData {
  const PathDailyReviewItem({
    required super.sortOrder,
    required this.completedAt,
    required this.isCompleted,
  });
  final DateTime? completedAt;
  final bool isCompleted;

  @override
  bool get isComplete => isCompleted;
}
```

- [ ] **Step 3: Update isAllComplete in PathUnitData**

DR should not block unit completion. Game/Treasure follow normal lock rules:

```dart
bool get isAllComplete {
  final requiredItems = items.where((i) {
    if (i is PathBookItem && booksExemptFromLock) return false;
    if (i is PathDailyReviewItem) return false;
    return true;
  });
  return requiredItems.every((i) => i.isComplete);
}
```

Remove the `specialComplete` check with `completedNodeTypes` — special nodes are now in the items list, not tracked separately.

- [ ] **Step 4: Add DR-related providers**

```dart
/// Fetches daily review completion history for current user
final pathDailyReviewsProvider = FutureProvider<List<_DrCompletion>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase.rpc(
    RpcFunctions.getPathDailyReviews,
    params: {'p_user_id': userId},
  );
  return (response as List).map((r) => _DrCompletion(
    scopeLpUnitId: r['scope_lp_unit_id'] as String,
    position: r['position'] as int,
    completedAt: DateTime.parse(r['completed_at'] as String),
  )).toList();
});

class _DrCompletion {
  final String scopeLpUnitId;
  final int position;
  final DateTime completedAt;
  const _DrCompletion({required this.scopeLpUnitId, required this.position, required this.completedAt});
}

/// Whether daily review is needed today (conditions: not done today + 10+ words due)
final dailyReviewNeededProvider = FutureProvider<bool>((ref) async {
  // Reuse existing daily review logic — check if there are 10+ words due for review
  // and DR hasn't been done today
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final drHistory = await ref.watch(pathDailyReviewsProvider.future);
  final today = DateTime.now();
  final doneToday = drHistory.any((dr) =>
      dr.completedAt.year == today.year &&
      dr.completedAt.month == today.month &&
      dr.completedAt.day == today.day);
  if (doneToday) return false;

  // Check if 10+ words are due for review (use existing provider if available)
  final dueCount = await ref.watch(dailyReviewDueCountProvider.future);
  return dueCount >= 10;
});
```

Note: `dailyReviewDueCountProvider` may already exist or need to be found — search for existing daily review word count logic.

- [ ] **Step 5: Update learningPathProvider — handle game/treasure items**

In the items-building loop, add cases for game and treasure:

```dart
} else if (item.itemType == LearningPathItemType.game) {
  final isCompleted = nodeCompletions[lpUnit.unitId]?.contains('game') ?? false;
  items.add(PathGameItem(
    sortOrder: item.sortOrder,
    isCompleted: isCompleted,
  ));
} else if (item.itemType == LearningPathItemType.treasure) {
  final isCompleted = nodeCompletions[lpUnit.unitId]?.contains('treasure') ?? false;
  items.add(PathTreasureItem(
    sortOrder: item.sortOrder,
    isCompleted: isCompleted,
  ));
}
```

- [ ] **Step 6: Update learningPathProvider — inject Daily Reviews**

After building the items list for a unit, inject DR nodes:

```dart
// Inject completed DRs from history
final drHistory = await ref.watch(pathDailyReviewsProvider.future);
final unitDrHistory = drHistory.where((dr) => dr.scopeLpUnitId == scopeLpUnitId).toList();

for (final dr in unitDrHistory) {
  items.add(PathDailyReviewItem(
    sortOrder: dr.position,
    completedAt: dr.completedAt,
    isCompleted: true,
  ));
}

// Inject today's pending DR if needed
final needsDr = await ref.watch(dailyReviewNeededProvider.future);
if (needsDr) {
  // Find position: just before the first locked non-exempt item
  final tempLocks = calculateLocks(
    items: items,
    sequentialLock: path.sequentialLock,
    booksExemptFromLock: path.booksExemptFromLock,
    isUnitLocked: false,
  );
  int drPosition = items.isEmpty ? 0 : items.last.sortOrder + 1;
  for (int i = 0; i < items.length; i++) {
    if (tempLocks[i] && !(items[i] is PathBookItem && path.booksExemptFromLock)) {
      // Use a position between the previous unlocked item and this locked one
      drPosition = items[i].sortOrder;
      break;
    }
  }

  // Only inject if not already a pending DR in this unit
  final hasPendingDr = items.any((i) => i is PathDailyReviewItem && !(i as PathDailyReviewItem).isCompleted);
  if (!hasPendingDr) {
    items.add(PathDailyReviewItem(
      sortOrder: drPosition,
      completedAt: null,
      isCompleted: false,
    ));
  }
}

// Re-sort (DRs now interleaved)
items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
```

- [ ] **Step 7: Remove nodeCompletions dependency for special nodes**

The `completedNodeTypes` field in `PathUnitData` may no longer be needed if game/treasure completion is tracked via `nodeCompletions` provider directly. Keep it for now but remove from `isAllComplete`.

- [ ] **Step 8: Verify provider compiles**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/presentation/providers/vocabulary_provider.dart`
Expect widget errors (Task 4 fixes).

- [ ] **Step 9: Commit**

```bash
git add lib/presentation/providers/
git commit -m "feat: extend PathItemData with Game/Treasure/DailyReview, add DR injection logic"
```

---

## Phase 3: Widget Refactor

### Task 4: Update learning_path widget for new item types

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/widgets/vocabulary/learning_path.dart`
- Modify: `/Users/wonderelt/Desktop/Owlio/lib/presentation/widgets/vocabulary/path_special_nodes.dart`

- [ ] **Step 1: Read both files**

Read `learning_path.dart` and `path_special_nodes.dart` to understand current rendering.

- [ ] **Step 2: Remove hardcoded special nodes section**

In `learning_path.dart`, find the section after the items loop that renders Daily Review, Game, and Treasure nodes (approximately lines 197-310). Remove this entire section — these nodes now come through the unified items loop.

- [ ] **Step 3: Add new cases to the items switch**

In the unified items loop, extend the switch:

```dart
switch (item) {
  case PathWordListItem(:final wordListWithProgress):
    // existing — render PathRow with PathNode

  case PathBookItem(:final bookWithProgress):
    // existing — render PathBookNode

  case PathGameItem(:final isCompleted):
    nodes.add(
      Positioned(
        top: y, left: 0, right: 0,
        child: PathGameNode(
          globalRowIndex: globalRowIndex,
          isLocked: isItemLocked,
          isComplete: isCompleted,
          isActive: isActive,
          onComplete: () => completePathNode(ref, unit.unit.id, 'game'),
        ),
      ),
    );

  case PathTreasureItem(:final isCompleted):
    nodes.add(
      Positioned(
        top: y, left: 0, right: 0,
        child: PathTreasureNode(
          isUnitComplete: isCompleted,
          isLocked: isItemLocked,
          isActive: isActive,
          unitId: unit.unit.id,
          unitColor: unit.unit.parsedColor,
        ),
      ),
    );

  case PathDailyReviewItem(:final completedAt, :final isCompleted):
    nodes.add(
      Positioned(
        top: y, left: 0, right: 0,
        child: PathDailyReviewNode(
          globalRowIndex: globalRowIndex,
          unitId: unit.unit.id,
          isLocked: false, // DR is never locked — it's a gate
          isComplete: isCompleted,
          isActive: !isCompleted && !foundActive,
          completedAt: completedAt,
        ),
      ),
    );
    if (!isCompleted && !foundActive) foundActive = true;
}
```

- [ ] **Step 4: Add DR gate check to PathNode tap handler**

In `path_node.dart`, when a word list node is tapped, check if DR is pending:

Read the file first to find the tap handler. Add before the existing navigation logic:

```dart
// Check if daily review is pending (gate behavior)
final drNeeded = ref.read(dailyReviewNeededProvider).valueOrNull ?? false;
if (drNeeded) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Daily Review'),
      content: const Text('Bugünlük kelime tekrarını tamamlamalısın!'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tamam'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            // Navigate to daily review
            context.push('/vocabulary/daily-review');
          },
          child: const Text('Daily Review\'a Git'),
        ),
      ],
    ),
  );
  return;
}
```

- [ ] **Step 5: Update PathDailyReviewNode to show date badge**

In `path_special_nodes.dart`, update or create `PathDailyReviewNode` to optionally show a completed date:

```dart
class PathDailyReviewNode extends StatelessWidget {
  final int globalRowIndex;
  final String unitId;
  final bool isLocked;
  final bool isComplete;
  final bool isActive;
  final DateTime? completedAt; // NEW: show date if completed
  ...
}
```

If `completedAt` is not null, show a small date badge under the node.

- [ ] **Step 6: Full compilation check**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze lib/`
Expected: 0 errors

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/
git commit -m "feat: render Game/Treasure/DR in unified loop, add DR gate behavior"
```

---

## Phase 4: Admin Panel

### Task 5: Add Game and Treasure to template tree-view

**Files:**
- Modify: `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/core/widgets/learning_path_tree_view.dart`
- Modify: `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/templates/screens/template_edit_screen.dart`

- [ ] **Step 1: Add Game/Treasure add buttons to tree-view**

In `_buildAddItemButtons` (or equivalent), add two new buttons after "Kitap Ekle":

```dart
OutlinedButton.icon(
  onPressed: () => _addGameNode(unitIndex),
  icon: const Icon(Icons.sports_esports),
  label: const Text('Oyun Ekle'),
),
OutlinedButton.icon(
  onPressed: () => _addTreasureNode(unitIndex),
  icon: const Icon(Icons.card_giftcard),
  label: const Text('Hazine Ekle'),
),
```

- [ ] **Step 2: Add the add methods**

```dart
void _addGameNode(int unitIndex) {
  final units = List<LearningPathUnitData>.from(widget.units);
  final items = List<LearningPathItemData>.from(units[unitIndex].items);
  items.add(LearningPathItemData(
    itemType: LearningPathItemType.game.dbValue,
    itemId: 'game_${DateTime.now().millisecondsSinceEpoch}', // pseudo ID
    itemName: 'Oyun',
    subtitle: 'Placeholder',
    sortOrder: items.length,
  ));
  _reassignItemSortOrders(items);
  units[unitIndex] = units[unitIndex].copyWith(items: items);
  _notifyChange(units);
}

void _addTreasureNode(int unitIndex) {
  // Same pattern with 'treasure' type
}
```

- [ ] **Step 3: Update item display in tree-view**

In `_buildItemTile`, handle game/treasure types:

```dart
final isGame = item.itemType == LearningPathItemType.game.dbValue;
final isTreasure = item.itemType == LearningPathItemType.treasure.dbValue;

// Icon selection
Icon leadingIcon;
if (isWordList) {
  leadingIcon = const Icon(Icons.text_snippet, size: 16);
} else if (isGame) {
  leadingIcon = const Icon(Icons.sports_esports, size: 16, color: Colors.purple);
} else if (isTreasure) {
  leadingIcon = const Icon(Icons.card_giftcard, size: 16, color: Colors.amber);
} else {
  leadingIcon = const Icon(Icons.menu_book, size: 16);
}
```

- [ ] **Step 4: Update template edit save to handle null FK items**

In `template_edit_screen.dart`'s `_handleSave`, the current logic checks `isWordList` to set `word_list_id` or `book_id`. Update to handle game/treasure (both FKs null):

```dart
final isWordList = item.itemType == LearningPathItemType.wordList.dbValue;
final isBook = item.itemType == LearningPathItemType.book.dbValue;

await supabase.from(DbTables.learningPathTemplateItems).insert({
  'id': const Uuid().v4(),
  'template_unit_id': templateUnitId,
  'item_type': item.itemType,
  'word_list_id': isWordList ? item.itemId : null,
  'book_id': isBook ? item.itemId : null,
  'sort_order': j,
});
```

- [ ] **Step 5: Update template edit load to handle game/treasure items**

In `_loadTemplate`, the items loading loop checks `isWordList` to decide how to read the item. Add handling for game/treasure:

```dart
if (isWordList) {
  // existing word list handling
} else if (itemType == LearningPathItemType.book.dbValue) {
  // existing book handling
} else {
  // game or treasure — no FK, just type and name
  itemId = itemRow['id'] as String; // use the template_item ID as pseudo itemId
  itemName = itemType == LearningPathItemType.game.dbValue ? 'Oyun' : 'Hazine';
  subtitle = 'Placeholder';
}
```

- [ ] **Step 6: Same updates for assignment screen save/load**

Apply the same game/treasure handling to `/Users/wonderelt/Desktop/Owlio/owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`.

- [ ] **Step 7: Verify**

```bash
cd /Users/wonderelt/Desktop/Owlio/owlio_admin && dart analyze lib/
```

- [ ] **Step 8: Commit**

```bash
git add owlio_admin/
git commit -m "feat(admin): add Game and Treasure as configurable template items"
```

---

## Execution Order

```
Task 1 (DB) → Task 2 (Shared) → Task 3 (Provider) → Task 4 (Widgets) → Task 5 (Admin)
```

All sequential — each depends on the previous.

**Total: 5 tasks, ~10 files**
