# Admin Badge Improvements — Design Spec

**Date:** 2026-03-24
**Status:** Approved
**Scope:** Admin panel badge management, shared package cleanup, DB migration

---

## Problem

1. `dailyLogin` badge condition type exists in the shared enum and DB CHECK constraint but is never evaluated in the `check_and_award_badges` SQL function — badges created with this type can never be earned
2. `levelCompleted` condition type works in SQL but is missing from the admin panel's badge edit form dropdown
3. `_getConditionLabel` helper is duplicated across 3 admin panel files
4. No way to see which students earned a specific badge (only per-user view exists)
5. Streak badges (3, 7, 30 days) don't align with streak milestones (7, 14, 30, 60, 100 days) — missing badges at 14, 60, 100 day milestones

## Solution

### 1. Remove `dailyLogin` Condition Type

**DB Migration:** Update CHECK constraint on `badges.condition_type` to remove `'daily_login'`.

```sql
-- Verify actual constraint name first:
-- SELECT conname FROM pg_constraint WHERE conrelid = 'badges'::regclass AND contype = 'c';
-- Expected: badges_condition_type_check (auto-generated from table_column_check pattern)
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
  CHECK (condition_type IN (
    'xp_total', 'streak_days', 'books_completed',
    'vocabulary_learned', 'perfect_scores', 'level_completed'
  ));
```

**Shared Package:** Remove `dailyLogin('daily_login')` from `BadgeConditionType` enum in `packages/owlio_shared/lib/src/enums/badge_condition_type.dart`.

**Main App Cleanup (required for compile):**
- `lib/data/models/badge/badge_model.dart` — remove `daily_login` case from `parseConditionType` switch and `dailyLogin` case from `conditionTypeToString` switch. Also replace both methods with calls to the shared enum's `fromDbValue()` / `.dbValue` to eliminate duplication.
- `lib/data/repositories/supabase/supabase_badge_repository.dart` — remove `BadgeConditionType.dailyLogin` case from `checkEarnableBadges` switch.
- `test/fixtures/badge_fixtures.dart` — change `'condition_type': 'daily_login'` to `'condition_type': 'xp_total'` in `minimalBadgeJson()`.

**Impact:** No badge uses this type, no user data references it. Only code cleanup required for compile.

### 2. Add `levelCompleted` to Admin Form

Add to `_conditionTypes` list in `badge_edit_screen.dart`:

```dart
(BadgeConditionType.levelCompleted.dbValue, 'Ulaşılan Seviye'),
```

Update `_categories` list to include all categories used in seed data. Final list:
```dart
static const _categories = [
  'achievement', 'streak', 'reading', 'vocabulary',
  'activities', 'xp', 'level', 'special',
];
```
Note: `activities`, `xp`, `level` are used in seed data but missing from the current dropdown. `achievement` and `special` are kept as valid general-purpose categories. This also fixes a pre-existing bug: editing badges with `category = 'level'` (e.g., "Level 5", "Level 10") crashes the dropdown because the value is not in the list.

### 3. Extract Shared Badge Helper

Create `owlio_admin/lib/core/utils/badge_helpers.dart` with two functions:

```dart
/// Short label for badge cards (e.g., "7 gün", "500 XP")
String getConditionLabel(String type, int value);

/// Descriptive helper text for the edit form (e.g., "Ardışık aktif gün sayısı")
String getConditionHelper(String type);
```

Both must cover all 6 remaining condition types (after `dailyLogin` removal), including `level_completed` which the current duplicated functions are missing. New cases:
- Label: `'level_completed'` → `'$value seviye'`
- Helper: `'level_completed'` → `'Ulaşılması gereken seviye'`

**Files to update:**
- `badge_list_screen.dart` — remove `_getConditionLabel`, import helper
- `badge_edit_screen.dart` — remove `_getConditionHelper`, import helper
- `collectibles_screen.dart` — remove `_conditionLabel`, import helper

### 4. Per-Badge Statistics on Edit Screen

Add an "Earned By" section to the badge edit screen's preview panel (right column, below existing preview card).

**RLS Note:** Both `user_badges` and `profiles` are already accessible to admins via school-scoped SELECT policies (all users share the same school). No additional RLS migration needed — the existing "Users can view schoolmate badges" and "Users can view profiles in their school" policies cover admin access.

**Provider:**

```dart
final badgeEarnedByProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, badgeId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
    .from(DbTables.userBadges)
    .select('earned_at, profiles(id, first_name, last_name)')
    .eq('badge_id', badgeId)
    .order('earned_at', ascending: false);
});
```

**UI:**
- Header: "Kazanan Ogrenciler (N)"
- List: "${first_name} ${last_name}" + earned_at date for each student
- Empty state: "Henuz kimse kazanmadi"
- Only shown when editing existing badge (not on create)

### 5. New Streak Badges (Migration)

Insert 3 new badges to align with streak milestones:

| Name | Slug | Description | Icon | Category | Condition | Value | XP |
|------|------|-------------|------|----------|-----------|-------|----|
| Streak Warrior | `streak-warrior` | Maintain a 14-day reading streak | fire | streak | streak_days | 14 | 150 |
| Streak Hero | `streak-hero` | Maintain a 60-day reading streak | fire | streak | streak_days | 60 | 750 |
| Streak Immortal | `streak-immortal` | Maintain a 100-day reading streak | fire | streak | streak_days | 100 | 1500 |

**After this change, streak badges and milestones align:**

| Days | Milestone XP Bonus | Badge | Badge XP |
|------|--------------------|-------|----------|
| 3 | — | Streak Starter | 30 |
| 7 | 50 | Streak Master | 100 |
| 14 | 100 | Streak Warrior | 150 |
| 30 | 200 | Streak Legend | 500 |
| 60 | 400 | Streak Hero | 750 |
| 100 | 1000 | Streak Immortal | 1500 |

**SQL INSERT:**

```sql
INSERT INTO badges (name, slug, description, icon, category, condition_type, condition_value, xp_reward)
VALUES
  ('Streak Warrior', 'streak-warrior', 'Maintain a 14-day reading streak', '🔥', 'streak', 'streak_days', 14, 150),
  ('Streak Hero', 'streak-hero', 'Maintain a 60-day reading streak', '🔥', 'streak', 'streak_days', 60, 750),
  ('Streak Immortal', 'streak-immortal', 'Maintain a 100-day reading streak', '🔥', 'streak', 'streak_days', 100, 1500)
ON CONFLICT (slug) DO NOTHING;
```

No changes needed to `check_and_award_badges` — it already evaluates `streak_days` against `current_streak`.

## Files Changed

### New Files
- `supabase/migrations/YYYYMMDD_admin_badge_improvements.sql` — CHECK constraint update + new badge inserts
- `owlio_admin/lib/core/utils/badge_helpers.dart` — shared helper functions

### Modified Files (Admin Panel)
- `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart` — add `levelCompleted` to dropdown, fix categories, add earned-by section, use shared helper
- `owlio_admin/lib/features/badges/screens/badge_list_screen.dart` — use shared helper
- `owlio_admin/lib/features/collectibles/screens/collectibles_screen.dart` — use shared helper

### Modified Files (Shared Package)
- `packages/owlio_shared/lib/src/enums/badge_condition_type.dart` — remove `dailyLogin`

### Modified Files (Main App — dailyLogin cleanup)
- `lib/data/models/badge/badge_model.dart` — remove `daily_login`/`dailyLogin` switch cases, replace with shared enum methods
- `lib/data/repositories/supabase/supabase_badge_repository.dart` — remove `BadgeConditionType.dailyLogin` case
- `test/fixtures/badge_fixtures.dart` — fix `daily_login` test fixture

### Not Changed
- `check_and_award_badges` SQL function (already handles `streak_days`)
- `update_user_streak` SQL function (milestone system untouched)
- `StreakEventDialog` (streak notification UI)
- Main app presentation layer (badge display, profile screens)

## Verification

```bash
# Admin panel compiles
cd owlio_admin && flutter analyze lib/

# Main app compiles (shared package change)
cd .. && dart analyze lib/

# Migration applies cleanly
supabase db push --dry-run

# No references to dailyLogin remain
grep -r "dailyLogin\|daily_login" packages/owlio_shared/lib/ owlio_admin/lib/ lib/ test/
# Expected: zero matches (migration SQL history files are exempt)
```
