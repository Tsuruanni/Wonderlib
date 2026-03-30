# Safe Scope Path Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the destructive delete-then-reinsert save in admin scope path editing with targeted INSERT/UPDATE/DELETE that preserves existing row IDs, preventing student data loss.

**Architecture:** Single function rewrite in `assignment_screen.dart`. On save, compare in-memory state (which carries DB row IDs) against current DB state, then issue only the necessary INSERT/UPDATE/DELETE operations. A debounce timer batches rapid auto-save triggers.

**Tech Stack:** Flutter (admin panel), Supabase (PostgreSQL), uuid, owlio_shared

---

## File Structure

| File | Change | Description |
|------|--------|-------------|
| `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart` | Modify | Rewrite `_saveLearningPath` (lines 441-500), add debounce, add assignment warning dialog |

No new files. No other files modified.

---

### Task 1: Add debounce timer for auto-save

**Files:**
- Modify: `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

- [ ] **Step 1: Add `dart:async` import**

At top of file (line 1 area), add:

```dart
import 'dart:async';
```

- [ ] **Step 2: Add timer field to state class**

In `_AssignmentScreenState` (after line 86 `bool _isSaving = false;`), add:

```dart
  Timer? _saveDebounceTimer;
```

- [ ] **Step 3: Add dispose override**

Add after the `_isScopeComplete` getter (after line 95):

```dart
  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    super.dispose();
  }
```

- [ ] **Step 4: Change onUnitsChanged to use debounce**

Replace the `onUnitsChanged` callback (lines 945-949):

Old:
```dart
              onUnitsChanged: (updatedUnits) {
                setState(() {
                  _learningPaths[pathIndex].units = updatedUnits;
                });
                _saveLearningPath(pathIndex);
              },
```

New:
```dart
              onUnitsChanged: (updatedUnits) {
                setState(() {
                  _learningPaths[pathIndex].units = updatedUnits;
                });
                _saveDebounceTimer?.cancel();
                _saveDebounceTimer = Timer(
                  const Duration(milliseconds: 500),
                  () => _saveLearningPath(pathIndex),
                );
              },
```

- [ ] **Step 5: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

Expected: No errors (existing behavior unchanged, save still fires but debounced)

- [ ] **Step 6: Commit**

```bash
git add owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart
git commit -m "refactor: add debounce timer for scope path auto-save"
```

---

### Task 2: Rewrite `_saveLearningPath` with targeted operations

**Files:**
- Modify: `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart:441-500`

- [ ] **Step 1: Replace the entire `_saveLearningPath` function**

Delete lines 441-500 (the old `_saveLearningPath`) and replace with:

```dart
  Future<void> _saveLearningPath(int pathIndex) async {
    final path = _learningPaths[pathIndex];
    if (path.id == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final pathId = path.id!;

      // ── 1. Fetch existing state from DB ──
      final existingUnitsResponse = await supabase
          .from(DbTables.scopeLearningPathUnits)
          .select('id')
          .eq('scope_learning_path_id', pathId);
      final existingUnitIds =
          existingUnitsResponse.map((r) => r['id'] as String).toSet();

      final existingItemsByUnit = <String, Set<String>>{};
      if (existingUnitIds.isNotEmpty) {
        final existingItemsResponse = await supabase
            .from(DbTables.scopeUnitItems)
            .select('id, scope_lp_unit_id')
            .inFilter('scope_lp_unit_id', existingUnitIds.toList());
        for (final item in existingItemsResponse) {
          final unitId = item['scope_lp_unit_id'] as String;
          existingItemsByUnit
              .putIfAbsent(unitId, () => <String>{})
              .add(item['id'] as String);
        }
      }

      // ── 2. Process units + items: INSERT new, UPDATE existing ──
      final memoryUnitIds = <String>{};

      for (int i = 0; i < path.units.length; i++) {
        final unit = path.units[i];

        if (unit.id == null) {
          // NEW unit → INSERT
          final newUnitId = const Uuid().v4();
          await supabase.from(DbTables.scopeLearningPathUnits).insert({
            'id': newUnitId,
            'scope_learning_path_id': pathId,
            'unit_id': unit.unitId,
            'sort_order': i,
            'tile_theme_id': unit.tileThemeId,
          });
          unit.id = newUnitId;

          // All items in a new unit are new → INSERT all
          for (int j = 0; j < unit.items.length; j++) {
            final item = unit.items[j];
            final newItemId = const Uuid().v4();
            final isWordList =
                item.itemType == LearningPathItemType.wordList.dbValue;
            final isBook =
                item.itemType == LearningPathItemType.book.dbValue;

            await supabase.from(DbTables.scopeUnitItems).insert({
              'id': newItemId,
              'scope_lp_unit_id': newUnitId,
              'item_type': item.itemType,
              'word_list_id': isWordList ? item.itemId : null,
              'book_id': isBook ? item.itemId : null,
              'sort_order': j,
            });
            item.id = newItemId;
          }
        } else {
          // EXISTING unit → UPDATE sort_order + tile_theme_id
          memoryUnitIds.add(unit.id!);
          await supabase
              .from(DbTables.scopeLearningPathUnits)
              .update({'sort_order': i, 'tile_theme_id': unit.tileThemeId})
              .eq('id', unit.id!);

          // Process items within this existing unit
          final existingItemIds = existingItemsByUnit[unit.id!] ?? {};
          final memoryItemIds = <String>{};

          for (int j = 0; j < unit.items.length; j++) {
            final item = unit.items[j];

            if (item.id == null) {
              // NEW item → INSERT
              final newItemId = const Uuid().v4();
              final isWordList =
                  item.itemType == LearningPathItemType.wordList.dbValue;
              final isBook =
                  item.itemType == LearningPathItemType.book.dbValue;

              await supabase.from(DbTables.scopeUnitItems).insert({
                'id': newItemId,
                'scope_lp_unit_id': unit.id!,
                'item_type': item.itemType,
                'word_list_id': isWordList ? item.itemId : null,
                'book_id': isBook ? item.itemId : null,
                'sort_order': j,
              });
              item.id = newItemId;
            } else {
              // EXISTING item → UPDATE sort_order
              memoryItemIds.add(item.id!);
              await supabase
                  .from(DbTables.scopeUnitItems)
                  .update({'sort_order': j})
                  .eq('id', item.id!);
            }
          }

          // DELETE removed items (items in DB but not in memory)
          final deletedItemIds = existingItemIds.difference(memoryItemIds);
          for (final itemId in deletedItemIds) {
            await supabase
                .from(DbTables.scopeUnitItems)
                .delete()
                .eq('id', itemId);
          }
        }
      }

      // ── 3. DELETE removed units (with assignment check) ──
      final deletedUnitIds = existingUnitIds.difference(memoryUnitIds);

      if (deletedUnitIds.isNotEmpty) {
        // Check for active assignments referencing any deleted unit
        final unitAssignments = await supabase
            .from(DbTables.assignments)
            .select('id, content_config')
            .eq('assignment_type', AssignmentType.unit.dbValue);

        final affectedCount = unitAssignments.where((a) {
          final config = a['content_config'] as Map<String, dynamic>?;
          return config != null &&
              deletedUnitIds.contains(config['scopeLpUnitId']);
        }).length;

        if (affectedCount > 0 && mounted) {
          final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Dikkat'),
                  content: Text(
                    'Silinen ünitelere bağlı $affectedCount aktif ödev var. '
                    'Devam ederseniz bu ödevler yetim kalır.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Devam',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ) ??
              false;

          if (!confirmed) {
            // Admin cancelled — reload to restore deleted units
            await _loadScopeAssignments();
            return;
          }
        }

        for (final unitId in deletedUnitIds) {
          await supabase
              .from(DbTables.scopeLearningPathUnits)
              .delete()
              .eq('id', unitId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${path.name}" kaydedildi'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Kaydetme hatası: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
```

- [ ] **Step 2: Verify**

Run: `cd /Users/wonderelt/Desktop/Owlio && dart analyze owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart
git commit -m "fix: rewrite scope path save to preserve existing row IDs

Replace delete-then-reinsert with targeted INSERT/UPDATE/DELETE.
Existing unit and item IDs are preserved, preventing CASCADE
deletion of path_daily_review_completions and orphaning of
assignment references.

Adds assignment warning dialog when deleting units that have
active unit-type assignments."
```

---

### Task 3: Manual integration testing

- [ ] **Step 1: Start the admin panel**

Run: `cd /Users/wonderelt/Desktop/Owlio/owlio_admin && flutter run -d chrome`

Navigate to `http://localhost:PORT/#/learning-paths` → Atamalar tab.

- [ ] **Step 2: Test — Reorder units**

1. Select a school/scope with an existing path that has 2+ units
2. Move a unit up or down
3. Verify: snackbar shows "kaydedildi"
4. Reload page → verify order persisted
5. Check DB: `SELECT id, sort_order FROM scope_learning_path_units WHERE scope_learning_path_id = '<id>' ORDER BY sort_order;` — IDs should be the SAME as before, only sort_order changed

- [ ] **Step 3: Test — Add a new item to existing unit**

1. In an existing unit, add a new word list
2. Verify: snackbar shows "kaydedildi"
3. Check DB: existing items retain their IDs, new item has a new ID
4. Verify `path_daily_review_completions` rows for this unit are NOT deleted

- [ ] **Step 4: Test — Remove an item from a unit**

1. Remove a word list from a unit
2. Verify: only that item's row is deleted from `scope_unit_items`
3. Verify: other items in the same unit retain their IDs

- [ ] **Step 5: Test — Add a new unit**

1. Add a new unit to the path
2. Verify: new unit gets an ID, existing units retain their IDs
3. Add items to the new unit, verify they save correctly

- [ ] **Step 6: Test — Remove a unit (no assignments)**

1. Remove a unit that has NO active assignments
2. Verify: unit and its items are deleted, no dialog shown
3. Verify: other units are untouched

- [ ] **Step 7: Test — Remove a unit (with assignments)**

1. Ensure a unit has an active unit-type assignment (create one via teacher panel if needed)
2. Remove that unit
3. Verify: warning dialog appears with assignment count
4. Click "İptal" → verify unit is restored (page reloads)
5. Remove again → click "Devam" → verify unit is deleted

- [ ] **Step 8: Test — Debounce**

1. Make 3 rapid changes (add item, reorder, add another item)
2. Verify: only 1 snackbar appears (not 3) — debounce batched them
3. Verify: all 3 changes are persisted correctly

- [ ] **Step 9: Commit verification results**

No code changes needed. If all tests pass, the implementation is complete.
