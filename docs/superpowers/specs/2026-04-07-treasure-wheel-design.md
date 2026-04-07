# Treasure Wheel — Spin & Win Feature

**Date:** 2026-04-07
**Status:** Approved

## Overview

Treasure nodes in the learning path currently do nothing when tapped — they just mark as "completed." This feature transforms them into a **Spin the Wheel** experience: the student taps the treasure node, a full-screen wheel appears, they spin it, and win a random reward (coins or card packs).

## Requirements

- One spin per treasure node (single-use, idempotent)
- Rewards: coins (various amounts) and card packs (various quantities)
- Wheel slices configured globally via admin panel (all treasure nodes share the same wheel)
- Weighted random selection — server-side (cheat-proof)
- Atomic RPC: spin + award + mark-complete in one transaction
- Main app UI in English, admin panel in Turkish

---

## 1. Database

### New Table: `treasure_wheel_slices`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID PK | Default `gen_random_uuid()` |
| `label` | TEXT NOT NULL | Display label (e.g., "50 Coins", "1 Card Pack") |
| `reward_type` | TEXT NOT NULL | `CHECK (reward_type IN ('coin', 'card_pack'))` |
| `reward_amount` | INT NOT NULL | Coin quantity or pack count |
| `weight` | INT NOT NULL | Probability weight (higher = more likely) |
| `color` | TEXT NOT NULL | Hex color code for slice rendering |
| `sort_order` | INT NOT NULL DEFAULT 0 | Display order on wheel |
| `is_active` | BOOL NOT NULL DEFAULT true | Active/inactive toggle |
| `created_at` | TIMESTAMPTZ NOT NULL DEFAULT NOW() | |

**RLS Policies:**
- SELECT: All authenticated users (students need slices to render the wheel)
- INSERT/UPDATE/DELETE: Admin only (`is_admin()` check)

**Constraints:**
- At least 2 active slices should exist for the wheel to function (enforced at app level, not DB)

### New RPC: `spin_treasure_wheel(p_user_id UUID, p_unit_id UUID)`

**Returns:** JSONB

**Logic:**
1. **Auth check:** `p_user_id = auth.uid()` — fail if mismatch
2. **Duplicate check:** Query `user_node_completions` for `(p_user_id, p_unit_id, 'treasure')` — if exists, raise `'ALREADY_CLAIMED'`
3. **Fetch active slices:** `SELECT * FROM treasure_wheel_slices WHERE is_active = true`
4. **Weighted random selection:** Sum all weights, generate random number, iterate to find winning slice
5. **Award reward:**
   - If `reward_type = 'coin'`: Call `award_coins_transaction(p_user_id, reward_amount, 'treasure_wheel', p_unit_id, slice_label)`
   - If `reward_type = 'card_pack'`: Call `open_card_pack(p_user_id, 0)` × `reward_amount` times (0 cost = free pack)
6. **Mark complete:** `INSERT INTO user_node_completions (user_id, unit_id, node_type) VALUES (p_user_id, p_unit_id, 'treasure')`
7. **Return result:**
```json
{
  "slice_index": 2,
  "slice_label": "50 Coins",
  "reward_type": "coin",
  "reward_amount": 50,
  "cards": null
}
```
For card_pack rewards, `cards` contains the array of opened cards (same format as `open_card_pack` response).

---

## 2. Domain & Data Layer

### Entities

**`TreasureWheelSlice`**
- `id`: String
- `label`: String
- `rewardType`: String (`'coin'` | `'card_pack'`)
- `rewardAmount`: int
- `weight`: int
- `color`: String (hex)
- `sortOrder`: int

**`TreasureSpinResult`**
- `sliceIndex`: int (which slice won — for animation targeting)
- `sliceLabel`: String
- `rewardType`: String
- `rewardAmount`: int
- `cards`: List<CardEntity>? (populated only for card_pack rewards)

### Models

**`TreasureWheelSliceModel`**
- `fromJson(Map<String, dynamic>)` → `TreasureWheelSliceModel`
- `toEntity()` → `TreasureWheelSlice`

**`TreasureSpinResultModel`**
- `fromJson(Map<String, dynamic>)` → `TreasureSpinResultModel`
- `toEntity()` → `TreasureSpinResult`

### Repository

**`TreasureRepository`** (abstract, domain layer):
- `getWheelSlices()` → `Future<Either<Failure, List<TreasureWheelSlice>>>`
- `spinWheel(String userId, String unitId)` → `Future<Either<Failure, TreasureSpinResult>>`

**`SupabaseTreasureRepository`** (data layer):
- `getWheelSlices()`: `supabase.from(DbTables.treasureWheelSlices).select().eq('is_active', true).order('sort_order')`
- `spinWheel()`: `supabase.rpc(RpcFunctions.spinTreasureWheel, params: {...})`

### UseCases

- **`GetWheelSlicesUseCase`** — Fetches active wheel slices for rendering
- **`SpinTreasureWheelUseCase`** — Executes the spin, returns result

---

## 3. Presentation Layer

### TreasureWheelScreen

Full-screen page. Navigated to from learning path when student taps a treasure node.

**Parameters:** `unitId: String`

**State Machine (`TreasureWheelPhase`):**

| Phase | Description |
|-------|-------------|
| `loading` | Fetching wheel slices from DB |
| `ready` | Wheel rendered, "Spin" button active |
| `spinning` | Wheel animating, RPC running in background |
| `revealing` | Wheel stopped on winning slice, highlight animation |
| `rewarded` | Reward animation playing (coin rain or card reveal) |
| `completed` | "Claim" button visible → navigates back to learning path |

### TreasureWheelProvider (StateNotifier)

```
TreasureWheelState:
  - phase: TreasureWheelPhase
  - slices: List<TreasureWheelSlice>
  - result: TreasureSpinResult?
  - error: String?
```

**Methods:**
- `loadSlices()` → Fetches slices, transitions to `ready`
- `spin(unitId)` → Transitions to `spinning`, calls RPC, on success transitions to `revealing`
- `showReward()` → Transitions to `rewarded`
- `complete()` → Invalidates `nodeCompletionsProvider`, transitions to `completed`

### TreasureWheel Widget (CustomPainter)

- **Drawing:** `CustomPainter` draws pie slices based on `List<TreasureWheelSlice>`
  - Each slice: arc segment with color fill, label text rotated to slice center
  - Slice angles proportional to total count (equal visual size, weight only affects probability)
- **Animation:** `AnimationController` with ~3-4 second duration
  - `CurvedAnimation` with `Curves.easeOutCubic` for natural deceleration
  - Target angle calculated from `result.sliceIndex` to land pointer on winning slice
  - Total rotation: multiple full spins + offset to target
- **Pointer:** Fixed triangle/arrow at top of wheel (not part of the rotating canvas)
- **Interaction:** "Spin" button centered below the wheel

### Reward Animations

- **Coin reward:** Coin particle effect (coins falling/flying) with amount text
- **Card pack reward:** Card reveal similar to existing pack opening — show cards won

### Navigation Integration

Current treasure node tap handler in learning path widgets calls `completePathNode()`. This changes to:

```dart
// Instead of completePathNode(ref, unit.unit.id, 'treasure')
Navigator.push(context, TreasureWheelScreen(unitId: unit.unit.id));
```

The RPC handles both reward + completion atomically, so `completePathNode()` is no longer needed for treasure nodes. After screen pops, `nodeCompletionsProvider` is already invalidated, so the learning path refreshes automatically.

---

## 4. Admin Panel

### New Page: Treasure Wheel Config (Turkish UI)

**Location:** New menu entry in admin sidebar — "Hazine Çarkı"

**Features:**
- **Dilim listesi:** Table view with CRUD operations
  - Columns: Label, Ödül Tipi (dropdown: Coin/Kart Paketi), Miktar, Ağırlık, Renk, Sıra, Aktif
  - Inline editing or dialog-based editing
  - Add/delete dilim buttons
- **Canlı çark önizlemesi:** Live preview wheel on the right side, updates as slices are edited
  - Uses the same `TreasureWheel` CustomPainter widget (shared between admin and main app via shared widget or copy)
- **Validations:**
  - At least 2 active slices required
  - reward_amount must be > 0
  - weight must be > 0
- **Drag & drop** reordering for sort_order

---

## 5. Shared Package Updates

Add to `owlio_shared`:
- `DbTables.treasureWheelSlices` → `'treasure_wheel_slices'`
- `RpcFunctions.spinTreasureWheel` → `'spin_treasure_wheel'`

---

## 6. Edge Cases & Error Handling

| Scenario | Handling |
|----------|----------|
| Student taps already-claimed treasure | Node shows as "CLAIMED" (existing behavior), navigation blocked |
| Network error during spin | Wheel stops, error message shown, "Try Again" button (RPC is idempotent — if completion was written, next attempt returns ALREADY_CLAIMED and we treat it as success) |
| No active wheel slices in DB | "Spin" button disabled, message: "No rewards available" |
| App killed during spin animation | On re-entry, if completion exists → node shows CLAIMED. If not → fresh spin available |
| RPC returns before animation ends | Result is stored, animation continues to calculated target angle |
| Card pack opening fails mid-way | RPC is atomic — either all rewards are given or none |

---

## 7. File Structure (Planned)

```
lib/
  domain/
    entities/
      treasure_wheel_slice.dart
      treasure_spin_result.dart
    repositories/
      treasure_repository.dart
    usecases/
      treasure/
        get_wheel_slices_usecase.dart
        spin_treasure_wheel_usecase.dart
  data/
    models/
      treasure_wheel_slice_model.dart
      treasure_spin_result_model.dart
    repositories/
      supabase/
        supabase_treasure_repository.dart
  presentation/
    providers/
      treasure_wheel_provider.dart
    screens/
      treasure/
        treasure_wheel_screen.dart
    widgets/
      treasure/
        treasure_wheel_painter.dart
        treasure_reward_overlay.dart

owlio_admin/
  lib/
    features/
      treasure_wheel/
        screens/
          treasure_wheel_config_screen.dart
        widgets/
          slice_editor_widget.dart

supabase/
  migrations/
    YYYYMMDD_create_treasure_wheel.sql

packages/owlio_shared/
  lib/src/constants/
    db_tables.dart        (add treasureWheelSlices)
    rpc_functions.dart    (add spinTreasureWheel)
```
