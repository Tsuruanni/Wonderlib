# Leaderboard/Leagues Audit Fixes Design

**Date**: 2026-03-28
**Scope**: Fix 8 of 10 audit findings from Feature #12 (skip #7 placeholder, #8 teacher perf)

---

## Issues Being Fixed

| # | Severity | Issue | Fix |
|---|----------|-------|-----|
| 1 | Medium | `process_weekly_league_reset` regression — debug-time migration lost tier-based algorithm | New migration: combine tier-based + temp table + `app_now()` |
| 2 | Medium | 8 read RPCs lack `auth.uid()` check — any user can query any school | Add auth verification to each RPC |
| 3 | Medium | Zone banner `totalCount` uses fetched entries (max 50), not real tier group size | Add `total_count` to weekly school leaderboard RPC; propagate to UI |
| 4 | Low | Duplicate `LeaderboardScope` enum in domain and presentation layers | Consolidate: keep `TotalLeaderboardScope` in use case, remove domain `LeaderboardScope`, rename provider enum |
| 5 | Low | `_leagueZoneSize()` duplicated between Dart and SQL | Add `leagueZoneSize()` to `owlio_shared` |
| 6 | Low | `leagueTier` param is raw `String?` instead of `LeagueTier` | Change to `LeagueTier?` in params, convert at data layer |
| 9 | Low | Stale class-based RLS policy on `league_history` | Drop in migration |
| 10 | Low | No retry button on leaderboard error | Use `ErrorStateWidget` with `onRetry` |

---

## Section 1: Database Migration

**File**: `supabase/migrations/YYYYMMDD000001_fix_leaderboard_audit.sql`

### 1a. Fix `process_weekly_league_reset()`

Rewrite the function combining all three versions:
- **Tier-based competition** from `20260218000003`: `FOR school` → `FOREACH tier` nested loop, zone size based on tier group count
- **Temp table optimization** from `20260316000010`: single-pass `CREATE TEMP TABLE tmp_weekly_xp` for XP aggregation
- **`app_now()` timestamps** from `20260323000006`: all date calculations use `app_now()` instead of `NOW()`

Key algorithm:
```
1. Idempotency check: EXISTS(league_history WHERE week_start = last_week)
2. CREATE TEMP TABLE tmp_weekly_xp (single-pass XP aggregation)
3. FOR each school:
     FOREACH tier IN [bronze, silver, gold, platinum, diamond]:
       count = students in school+tier
       zone_size = threshold(count)
       RANK students by weekly_xp DESC, total_xp DESC
       top zone_size → promote (unless diamond)
       bottom zone_size → demote (unless bronze)
       INSERT league_history
       UPDATE profiles.league_tier if changed
4. DROP TEMP TABLE
```

### 1b. Auth checks on 8 read RPCs

Each RPC gets an auth guard at the top of the function body:

**School-scoped RPCs** (`get_school_leaderboard`, `get_weekly_school_leaderboard`, `get_user_school_position`, `get_user_weekly_school_position`):
```sql
IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND school_id = p_school_id
) THEN
    RAISE EXCEPTION 'Access denied: caller does not belong to this school';
END IF;
```

**Class-scoped RPCs** (`get_class_leaderboard`, `get_weekly_class_leaderboard`, `get_user_class_position`, `get_user_weekly_class_position`):
```sql
IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND class_id = p_class_id
) THEN
    RAISE EXCEPTION 'Access denied: caller does not belong to this class';
END IF;
```

Note: Class RPCs check `class_id` only. A teacher viewing a class leaderboard has `class_id = NULL`, so they'd be blocked. However, the teacher report uses a completely separate data path (`getStudentsInClass` RPC), so this is not a problem — teachers never call the student leaderboard RPCs.

The RPCs also need `NOW()` → `app_now()` in the weekly RPCs (carried forward from avatar migration which still uses `NOW()`).

### 1c. Add `total_count` to weekly school leaderboard RPC

Modify `get_weekly_school_leaderboard` to return an additional `total_count` column:
```sql
-- Add to RETURNS TABLE:
total_count BIGINT

-- Compute before the main query:
SELECT COUNT(*) INTO v_total_count
FROM profiles
WHERE school_id = p_school_id AND role = 'student'
AND (p_league_tier IS NULL OR league_tier = p_league_tier);

-- Include in SELECT:
v_total_count AS total_count  -- same value for every row
```

This is a non-breaking addition — existing columns are unchanged, the new column is simply appended. The client can read it from the first row of results.

### 1d. Drop stale RLS policy

```sql
DROP POLICY IF EXISTS "Users can read classmates league history" ON league_history;
```

---

## Section 2: Shared Package Changes

### 2a. Add `leagueZoneSize()` to owlio_shared

**File**: `packages/owlio_shared/lib/src/constants/league_constants.dart`

```dart
/// Zone size for league promotion/demotion.
/// Must match process_weekly_league_reset() in SQL.
int leagueZoneSize(int groupSize) {
  if (groupSize < 10) return 1;
  if (groupSize <= 25) return 2;
  if (groupSize <= 50) return 3;
  return 5;
}
```

Export from `owlio_shared.dart`.

### 2b. Enum cleanup approach

The current situation:
- `get_weekly_leaderboard_usecase.dart` defines `enum LeaderboardScope { classScope, schoolScope }`
- `get_total_leaderboard_usecase.dart` defines `enum TotalLeaderboardScope { classScope, schoolScope }`
- `leaderboard_provider.dart` defines `enum LeaderboardScope { classScope, schoolScope, leagueScope }`
- Provider imports weekly usecase with `as weekly` alias to avoid collision

**Fix**: The two domain-layer enums (`LeaderboardScope` with 2 values, `TotalLeaderboardScope` with 2 values) are used only within their respective use case files. They serve as scope discriminators — class vs school. The presentation-layer enum adds `leagueScope` which is a UI-only concept (it maps to the weekly school leaderboard with a tier filter).

Plan:
1. Rename the domain-layer `LeaderboardScope` (in `get_weekly_leaderboard_usecase.dart`) to `WeeklyLeaderboardScope` to avoid name collision
2. Keep `TotalLeaderboardScope` as-is (already unique)
3. Keep the presentation-layer `LeaderboardScope` as-is (it's the UI concept)
4. Remove the `as weekly` import alias from `leaderboard_provider.dart`

This is the minimal change that eliminates the collision without moving files to the shared package (these enums are internal to the app, not shared with admin).

---

## Section 3: Domain/Data Layer Changes

### 3a. `LeaderboardEntry` entity — add `totalCount`

```dart
class LeaderboardEntry extends Equatable {
  // ... existing fields ...
  final int? totalCount; // Total students in the group (for zone calculation)
}
```

### 3b. `LeaderboardEntryModel.fromJson` — parse `total_count`

```dart
totalCount: (json['total_count'] as num?)?.toInt(),
```

### 3c. UseCase params — `leagueTier` type change

In `GetWeeklyLeaderboardParams` and `GetUserWeeklyPositionParams`:
```dart
// Before:
final String? leagueTier;

// After:
final LeagueTier? leagueTier;
```

### 3d. Repository — convert at data boundary

In `SupabaseUserRepository.getWeeklySchoolLeaderboard`:
```dart
// Before:
if (leagueTier != null) params['p_league_tier'] = leagueTier;

// After:
if (leagueTier != null) params['p_league_tier'] = leagueTier.dbValue;
```

Same for `getUserWeeklySchoolPosition`.

Repository interface changes `String? leagueTier` → `LeagueTier? leagueTier`.

### 3e. Provider — convert `LeagueTier` at call site

In `leaderboard_provider.dart`, the `leagueTier:` argument changes from `currentUser.leagueTier.dbValue` to `currentUser.leagueTier`.

---

## Section 4: Presentation Layer Changes

### 4a. Propagate `totalCount` into `LeaderboardDisplayState`

```dart
class LeaderboardDisplayState {
  // ... existing fields ...
  final int? leagueTotalCount; // Total students in the league tier group
}
```

In `leaderboardDisplayProvider`, extract `totalCount` from the first entry when in league mode:
```dart
leagueTotalCount: scope == LeaderboardScope.leagueScope && entries.isNotEmpty
    ? entries.first.totalCount
    : null,
```

### 4b. Zone calculation fix

In `leaderboard_screen.dart`:
- Remove local `_leagueZoneSize()` function
- Import `leagueZoneSize` from `owlio_shared`
- Replace `state.totalCount` with `state.leagueTotalCount ?? state.totalCount` in `_ZonePreviewBanner` and `_buildEntryCard`

### 4c. Error state retry

Replace the error Text widget:
```dart
// Before:
error: (e, _) => Center(
  child: Text('Could not load leaderboard', ...),
),

// After:
error: (e, _) => ErrorStateWidget(
  message: 'Could not load leaderboard',
  onRetry: () => ref.invalidate(leaderboardDisplayProvider),
),
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Migration breaks live data | `--dry-run` first; all RPCs use `CREATE OR REPLACE` (no data loss); league reset has idempotency guard |
| Auth check blocks teachers | Teachers use separate data path (`getStudentsInClass`), never call student leaderboard RPCs |
| `total_count` breaks existing clients | Additive column — existing code ignores unknown fields; `fromJson` parses it as nullable |
| Zone size function mismatch | Single source of truth in `owlio_shared`; SQL comment references the shared constant |
