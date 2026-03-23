# Debug Time Offset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a system-wide debug time offset (integer days) that shifts all date/time functions across server RPCs and Flutter client, enabling testing of time-dependent features.

**Architecture:** Two PostgreSQL helper functions (`app_current_date()`, `app_now()`) read offset from `system_settings` and replace `CURRENT_DATE`/`NOW()` in all business-logic RPCs. A Flutter `AppClock` utility applies the same offset client-side. Admin panel controls the offset via existing settings UI.

**Tech Stack:** Supabase PostgreSQL (RPCs), Flutter/Riverpod, owlio_shared constants.

**Spec:** `docs/superpowers/specs/2026-03-23-debug-time-offset-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `supabase/migrations/20260323000006_debug_time_offset.sql` | Helper functions, setting, all RPC replacements |
| Create | `lib/core/utils/app_clock.dart` | Flutter clock utility |
| Modify | `lib/domain/entities/system_settings.dart` | Add `debugDateOffset` field |
| Modify | `lib/data/models/settings/system_settings_model.dart` | Parse `debug_date_offset` |
| Modify | `lib/presentation/providers/system_settings_provider.dart` | Call `AppClock.setOffset()` on load |
| Modify | `lib/core/utils/sm2_algorithm.dart` | `DateTime.now()` → `AppClock.now()` |
| Modify | `lib/domain/entities/assignment.dart` | `DateTime.now()` → `AppClock.now()` |
| Modify | `lib/domain/entities/student_assignment.dart` | `DateTime.now()` → `AppClock.now()` |
| Modify | `lib/domain/entities/vocabulary.dart` | `DateTime.now()` → `AppClock.now()` |
| Modify | `lib/presentation/widgets/common/streak_status_dialog.dart` | `DateTime.now()` → `AppClock.now()` |
| Modify | `lib/presentation/widgets/home/daily_quest_list.dart` | `DateTime.now()` → `AppClock.now()` |
| Modify | `lib/presentation/screens/vocabulary/vocabulary_screen.dart` | `DateTime.now()` → `AppClock.now()` |

---

## Task 1: Database Migration — Helper Functions + RPC Updates

**Files:**
- Create: `supabase/migrations/20260323000006_debug_time_offset.sql`

This is the largest task — it creates helper functions, adds the setting, and re-creates all 8 RPCs with `app_current_date()`/`app_now()` replacing `CURRENT_DATE`/`NOW()`.

- [ ] **Step 1: Write the migration**

The migration must:
1. Create `app_current_date()` and `app_now()` helper functions
2. Insert `debug_date_offset` setting
3. Re-create each RPC using the helpers

**Important:** For each RPC, you must read the **latest version** from the most recent migration that defined it. Several RPCs have been redefined across multiple migrations. Use `CREATE OR REPLACE` for each.

The RPCs to update (read each one's latest definition, replace `CURRENT_DATE` with `app_current_date()` and `NOW()` with `app_now()`):

| RPC | Latest migration | What to replace |
|-----|-----------------|-----------------|
| `update_user_streak` | `20260323000005_streak_freeze_and_milestones.sql` | `CURRENT_DATE` → `app_current_date()` |
| `get_daily_quest_progress` | `20260323000002_update_quest_types.sql` | `CURRENT_DATE` → `app_current_date()`, `NOW()` → `app_now()` |
| `claim_daily_bonus` | `20260322000003_daily_quest_engine.sql` | `CURRENT_DATE` → `app_current_date()` |
| `complete_daily_review` | `20260203000001_add_daily_review_sessions.sql` | `CURRENT_DATE` → `app_current_date()` |
| `complete_vocabulary_session` | `20260317000001_fix_session_sm2_interval_growth.sql` | `NOW()` → `app_now()` |
| `get_quest_completion_stats` | `20260323000004_quest_admin_stats_rpc.sql` | `CURRENT_DATE` → `app_current_date()` |
| `get_words_due_for_review` | `20260131000010_create_functions.sql` | `NOW()` → `app_now()` |
| `process_weekly_league_reset` | `20260218000001_league_school_based_reset.sql` | `NOW()` → `app_now()` |

**Do NOT replace:**
- `DEFAULT NOW()` on column definitions
- `updated_at = NOW()` in UPDATE statements
- `NOW()` in `award_xp_transaction`, `spend_coins_transaction`, `award_coins_transaction`
- `NOW()` in `buy_streak_freeze` (the `updated_at = NOW()` line)

**Approach:** Read each RPC's latest definition from the migration file listed above. Copy the full function body. Replace only the business-logic `CURRENT_DATE` / `NOW()` calls. Leave everything else identical.

For `update_user_streak`: it was last modified in `20260323000005`. Its return type changed, so use `DROP FUNCTION IF EXISTS update_user_streak(UUID);` before `CREATE OR REPLACE`.

Wait — `update_user_streak` was already dropped and recreated in `20260323000005` with the new return type. Since we're not changing the return type here, `CREATE OR REPLACE` is sufficient.

For `complete_vocabulary_session` and `complete_daily_review`: these are large functions. Read the full latest version from the migration files listed above.

For `process_weekly_league_reset`: read from `20260218000001_league_school_based_reset.sql`.

Start the migration with:

```sql
-- =============================================
-- Debug Time Offset — System-wide time manipulation for testing
-- =============================================

-- 1. Helper functions
CREATE OR REPLACE FUNCTION app_current_date() RETURNS DATE AS $$
  SELECT (CURRENT_DATE + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ))::DATE;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION app_current_date IS 'Returns CURRENT_DATE + debug offset days. Use instead of CURRENT_DATE in business logic.';

CREATE OR REPLACE FUNCTION app_now() RETURNS TIMESTAMPTZ AS $$
  SELECT NOW() + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ) * INTERVAL '1 day';
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION app_now IS 'Returns NOW() + debug offset days. Use instead of NOW() in business logic.';

-- 2. Setting
INSERT INTO system_settings (key, value, category, description) VALUES
  ('debug_date_offset', '0', 'app', 'Debug: shift all date/time by N days (0 = production)')
ON CONFLICT (key) DO NOTHING;

-- 3. Update all RPCs below...
```

Then for each RPC, add `CREATE OR REPLACE FUNCTION ...` with the replacement. Read each file to get the full function body.

- [ ] **Step 2: Dry-run**

Run: `supabase db push --dry-run`
Expected: Shows migration as pending.

- [ ] **Step 3: Push**

Run: `supabase db push`
Expected: Applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260323000006_debug_time_offset.sql
git commit -m "feat(db): add app_current_date/app_now helpers, replace CURRENT_DATE/NOW in all business RPCs"
```

---

## Task 2: Flutter — AppClock Utility + SystemSettings

**Files:**
- Create: `lib/core/utils/app_clock.dart`
- Modify: `lib/domain/entities/system_settings.dart`
- Modify: `lib/data/models/settings/system_settings_model.dart`
- Modify: `lib/presentation/providers/system_settings_provider.dart`

- [ ] **Step 1: Create AppClock**

```dart
// lib/core/utils/app_clock.dart

/// Debug-aware clock utility.
/// All business logic should use AppClock.now() instead of DateTime.now().
/// Offset is set from SystemSettings.debugDateOffset on app load.
class AppClock {
  static int _offsetDays = 0;

  /// Set the debug offset in days. Called once from systemSettingsProvider.
  static void setOffset(int days) => _offsetDays = days;

  /// Current offset in days (for display purposes).
  static int get offsetDays => _offsetDays;

  /// Returns DateTime.now() shifted by offset days.
  static DateTime now() => DateTime.now().add(Duration(days: _offsetDays));

  /// Returns today at midnight, shifted by offset.
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}
```

- [ ] **Step 2: Add debugDateOffset to SystemSettings entity**

In `lib/domain/entities/system_settings.dart`:

Add to constructor (after `featureAchievements`):
```dart
    this.debugDateOffset = 0,
```

Add field:
```dart
  // Debug
  final int debugDateOffset;
```

Add to props list:
```dart
        debugDateOffset,
```

- [ ] **Step 3: Add to SystemSettingsModel**

In `lib/data/models/settings/system_settings_model.dart`:

Add `required this.debugDateOffset` to constructor.
Add field: `final int debugDateOffset;`

In `fromMap`, add:
```dart
      debugDateOffset: _toInt(m['debug_date_offset'], 0),
```

In `defaults()`, add:
```dart
        debugDateOffset: 0,
```

In `toEntity()`, add:
```dart
        debugDateOffset: debugDateOffset,
```

In `fromEntity()`, add:
```dart
        debugDateOffset: e.debugDateOffset,
```

- [ ] **Step 4: Initialize AppClock from systemSettingsProvider**

In `lib/presentation/providers/system_settings_provider.dart`, add import:
```dart
import '../../core/utils/app_clock.dart';
```

In the `systemSettingsProvider` body, after `return result.fold(...)`, modify so that on success it calls `AppClock.setOffset`:

Change the provider to:
```dart
final systemSettingsProvider = FutureProvider<SystemSettings>((ref) async {
  final useCase = ref.watch(getSystemSettingsUseCaseProvider);
  final result = await useCase(const NoParams());

  return result.fold(
    (failure) {
      AppClock.setOffset(0);
      return SystemSettings.defaults();
    },
    (settings) {
      AppClock.setOffset(settings.debugDateOffset);
      return settings;
    },
  );
});
```

- [ ] **Step 5: Verify**

Run: `dart analyze lib/core/utils/app_clock.dart lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart lib/presentation/providers/system_settings_provider.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/utils/app_clock.dart lib/domain/entities/system_settings.dart lib/data/models/settings/system_settings_model.dart lib/presentation/providers/system_settings_provider.dart
git commit -m "feat: add AppClock utility, debugDateOffset in SystemSettings, auto-init on load"
```

---

## Task 3: Flutter — Replace DateTime.now() in Business Logic

**Files:**
- Modify: `lib/core/utils/sm2_algorithm.dart:112-113`
- Modify: `lib/domain/entities/assignment.dart:42-45`
- Modify: `lib/domain/entities/student_assignment.dart:101-114`
- Modify: `lib/domain/entities/vocabulary.dart:106`
- Modify: `lib/presentation/widgets/common/streak_status_dialog.dart` (weekly calendar)
- Modify: `lib/presentation/widgets/home/daily_quest_list.dart:607`
- Modify: `lib/presentation/screens/vocabulary/vocabulary_screen.dart:232`

- [ ] **Step 1: SM2 algorithm**

In `lib/core/utils/sm2_algorithm.dart`, add import:
```dart
import 'app_clock.dart';
```

Replace lines 112-113:
```dart
      nextReviewAt: DateTime.now().add(Duration(days: newInterval)),
      lastReviewedAt: DateTime.now(),
```
With:
```dart
      nextReviewAt: AppClock.now().add(Duration(days: newInterval)),
      lastReviewedAt: AppClock.now(),
```

- [ ] **Step 2: Assignment entity**

In `lib/domain/entities/assignment.dart`, add import:
```dart
import '../../core/utils/app_clock.dart';
```

Replace lines 42-45:
```dart
  bool get isOverdue => DateTime.now().isAfter(dueDate);
  bool get isActive =>
      DateTime.now().isAfter(startDate) && DateTime.now().isBefore(dueDate);
  bool get isUpcoming => DateTime.now().isBefore(startDate);
```
With:
```dart
  bool get isOverdue => AppClock.now().isAfter(dueDate);
  bool get isActive =>
      AppClock.now().isAfter(startDate) && AppClock.now().isBefore(dueDate);
  bool get isUpcoming => AppClock.now().isBefore(startDate);
```

- [ ] **Step 3: StudentAssignment entity**

In `lib/domain/entities/student_assignment.dart`, add import:
```dart
import '../../core/utils/app_clock.dart';
```

Replace lines 101-114:
```dart
  bool get isOverdue =>
      status != StudentAssignmentStatus.completed &&
      DateTime.now().isAfter(dueDate);

  bool get isActive =>
      DateTime.now().isAfter(startDate) && DateTime.now().isBefore(dueDate);

  bool get isUpcoming => DateTime.now().isBefore(startDate);

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(dueDate)) return 0;
    return dueDate.difference(now).inDays;
  }
```
With:
```dart
  bool get isOverdue =>
      status != StudentAssignmentStatus.completed &&
      AppClock.now().isAfter(dueDate);

  bool get isActive =>
      AppClock.now().isAfter(startDate) && AppClock.now().isBefore(dueDate);

  bool get isUpcoming => AppClock.now().isBefore(startDate);

  int get daysRemaining {
    final now = AppClock.now();
    if (now.isAfter(dueDate)) return 0;
    return dueDate.difference(now).inDays;
  }
```

- [ ] **Step 4: Vocabulary entity**

In `lib/domain/entities/vocabulary.dart`, add import:
```dart
import '../../core/utils/app_clock.dart';
```

Replace line 106:
```dart
    return DateTime.now().isAfter(nextReviewAt!);
```
With:
```dart
    return AppClock.now().isAfter(nextReviewAt!);
```

- [ ] **Step 5: Streak status dialog**

In `lib/presentation/widgets/common/streak_status_dialog.dart`, add import:
```dart
import '../../../core/utils/app_clock.dart';
```

In `_buildWeekRow()`, replace:
```dart
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
```
With:
```dart
    final now = AppClock.now();
    final today = AppClock.today();
```

- [ ] **Step 6: Daily quest list**

In `lib/presentation/widgets/home/daily_quest_list.dart`, add import:
```dart
import '../../../core/utils/app_clock.dart';
```

Replace line 607:
```dart
    final daysLeft = a.dueDate.difference(DateTime.now()).inDays;
```
With:
```dart
    final daysLeft = a.dueDate.difference(AppClock.now()).inDays;
```

- [ ] **Step 7: Vocabulary screen**

In `lib/presentation/screens/vocabulary/vocabulary_screen.dart`, add import:
```dart
import '../../../core/utils/app_clock.dart';
```

Replace lines 232-233:
```dart
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
```
With:
```dart
    final now = AppClock.now();
    final today = AppClock.today();
```

- [ ] **Step 8: Verify**

Run: `dart analyze lib/`
Expected: No new errors.

- [ ] **Step 9: Commit**

```bash
git add lib/core/utils/sm2_algorithm.dart lib/domain/entities/assignment.dart lib/domain/entities/student_assignment.dart lib/domain/entities/vocabulary.dart lib/presentation/widgets/common/streak_status_dialog.dart lib/presentation/widgets/home/daily_quest_list.dart lib/presentation/screens/vocabulary/vocabulary_screen.dart
git commit -m "feat: replace DateTime.now() with AppClock.now() in all business logic"
```

---

## Task 4: Final Verification

- [ ] **Step 1: Full analyze**

Run: `dart analyze lib/`
Expected: No new errors.

- [ ] **Step 2: Push migration**

Run: `supabase db push --dry-run` then `supabase db push`
Expected: Applied.

- [ ] **Step 3: Manual test**

1. Admin panel → Settings → set `debug_date_offset` to `2`
2. Open main app → streak should behave as if 2 days in the future
3. Daily quests should reset (new day)
4. Set offset back to `0` → everything returns to normal
