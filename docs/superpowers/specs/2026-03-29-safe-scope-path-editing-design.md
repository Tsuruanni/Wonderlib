# Safe Scope Path Editing

## Problem

When an admin edits an already-assigned scope learning path in the admin panel (add/remove/reorder units or items), the `_saveLearningPath` function uses a **delete-then-reinsert** strategy: it deletes ALL `scope_learning_path_units` rows (cascading to `scope_unit_items`), then reinserts them with **new UUIDs**.

This causes:
1. **DR progress loss** — `path_daily_review_completions` rows CASCADE-deleted (FK on `scope_lp_unit_id`)
2. **Assignment FK breakage** — `assignments.scope_lp_unit_id` references the old (now deleted) unit IDs
3. **Game/treasure completion orphaning** — `user_node_completions` rows referencing old unit IDs become orphaned (if keyed by scope unit ID)

## Solution

Replace delete-then-reinsert with **targeted INSERT / UPDATE / DELETE** that preserves existing row IDs.

### Save Algorithm

```
On save:
  1. SELECT existing unit IDs from DB for this scope path
  2. For each unit in memory:
     - id == null → INSERT (new unit, generate UUID)
     - id != null → UPDATE sort_order, tile_theme_id
  3. For each unit in memory, repeat for items:
     - id == null → INSERT (new item, generate UUID)
     - id != null → UPDATE sort_order
  4. Deleted units = DB unit IDs − memory unit IDs
     - For each deleted unit: check for active assignments → warn admin
     - If admin confirms (or no assignments): DELETE
  5. Deleted items = DB item IDs per unit − memory item IDs per unit
     - DELETE removed items (no assignment check needed, assignments are unit-level)
```

### Assignment Warning on Unit Deletion

When a unit is being removed and it has active assignments:

```
Dialog: "Bu uniteye bagli X aktif odev var. Devam edersen odevler yetim kalir. Devam edilsin mi?"
  - [Iptal] → skip deletion, keep unit
  - [Devam] → delete unit (assignments become orphaned — no CASCADE, scope_lp_unit_id is stored in JSONB content_config, not as a FK column)
```

Note: `assignments.content_config->>'scopeLpUnitId'` stores the reference as JSONB, not as a database-level FK. This means deleting a scope unit does NOT cascade-delete the assignment row — instead the assignment keeps a dangling reference to a non-existent unit.

Item deletion does NOT trigger a warning. Removing an item from a unit will change the assignment progress percentage (denominator shrinks) — this is accepted behavior.

### Auto-save Behavior

The existing `onUnitsChanged` auto-save pattern is preserved. Each tree change triggers `_saveLearningPath`, which now performs targeted operations instead of a full rewrite. Since each operation is a targeted INSERT/UPDATE/DELETE, auto-save is safe.

## Scope

### Changed Files

| File | Change |
|------|--------|
| `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart` | Rewrite `_saveLearningPath` function |

### NOT Changed

- `LearningPathTreeView` widget — untouched (shared with template editor)
- Template save (`template_edit_screen.dart`) — untouched (templates have no student data)
- Student-facing code — untouched
- RPCs — untouched
- Database schema — no migration needed

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Admin adds a unit | INSERT new `scope_learning_path_units` + its items. Existing data untouched. |
| Admin removes a unit with active assignments | Warning dialog shown. If admin proceeds, unit is deleted but assignment row remains with orphaned `scopeLpUnitId` in JSONB (no FK CASCADE). |
| Admin removes a unit without assignments | Unit and its items deleted. DR completions for that unit CASCADE-deleted (expected — unit no longer exists). |
| Admin reorders units | UPDATE `sort_order` on affected units. IDs preserved. Sequential lock recalculates client-side on student app. |
| Admin adds an item to existing unit | INSERT new `scope_unit_items` row. Existing items untouched. |
| Admin removes an item from a unit | DELETE that item row. Unit assignment progress % recalculates (smaller denominator). |
| Admin reorders items in a unit | UPDATE `sort_order` on affected items. IDs preserved. |
| Network failure mid-save | Partial state possible (same as current behavior). Individual operations are atomic at row level. |
| Concurrent admin + student | Student completes a node while admin saves. No conflict — admin updates sort_order/inserts/deletes different rows than student writes to (progress tables). |

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Save strategy | Targeted INSERT/UPDATE/DELETE | Preserves row IDs, prevents CASCADE data loss |
| Assignment conflict | Warn but allow | Admin has final authority, blocking is too restrictive |
| Lock recalculation warning | None (silent) | Sequential lock is existing behavior, admin understands it |
| Template save | Not changed | Templates have no student progress data, delete-reinsert is harmless there |
| Detect deletions | Compare DB state at save time | Avoids modifying shared TreeView widget or tracking previous state in memory |
