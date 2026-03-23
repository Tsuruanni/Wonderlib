# Debug Time Offset — Design Spec

**Date:** 2026-03-23
**Scope:** System-wide debug time offset for testing time-dependent features. Single integer (days) shifts all date/time functions across server and client.

---

## Problem

Time-dependent features (streaks, daily quests, spaced repetition, league resets) are hard to test because they depend on calendar days. Currently there is no way to simulate "tomorrow" or "3 days ago" without manual SQL manipulation. Each RPC uses `CURRENT_DATE` or `NOW()` directly — there is no centralized time abstraction.

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Offset type | Integer (days) | All business logic operates on day boundaries. Hour precision unnecessary. |
| Scope | Server (RPCs) + client (Flutter) | Both sides must agree on "today" for coherent testing. |
| Storage | `system_settings` table, `app` category | Auto-renders in admin panel. Single place to change. |
| Default | 0 (no offset = production behavior) | Zero offset = transparent. No risk of accidental time shift. |
| What NOT to shift | `created_at`/`updated_at` defaults, cache timestamps, session durations | These should always reflect real wall-clock time. |

---

## Design

### Database — Helper Functions

Two new `STABLE` SQL functions that read the offset once per transaction:

```sql
CREATE FUNCTION app_current_date() RETURNS DATE AS $$
  SELECT (CURRENT_DATE + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ))::DATE;
$$ LANGUAGE sql STABLE;

CREATE FUNCTION app_now() RETURNS TIMESTAMPTZ AS $$
  SELECT NOW() + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ) * INTERVAL '1 day';
$$ LANGUAGE sql STABLE;
```

`STABLE` tells PostgreSQL the function returns the same result within a single SQL statement, enabling query optimization. `COALESCE` ensures graceful fallback to 0 if the setting row is missing.

**Transaction scoping note:** Since both functions are `STABLE`, PostgreSQL caches the offset within a transaction. Changing the offset in admin panel takes effect on the next RPC call, not within already-executing transactions. This is the desired behavior — no mid-transaction time jumps.

### Database — New Setting

```sql
INSERT INTO system_settings (key, value, category, description) VALUES
  ('debug_date_offset', '0', 'app', 'Debug: shift all date/time by N days (0 = production)');
```

Appears in admin panel under `app` category automatically. Reasonable range: -365 to +365. No DB constraint needed — admin-only setting, validated by common sense.

### Database — RPC Replacements

Every RPC that uses `CURRENT_DATE` or `NOW()` for business logic is updated:

| RPC | File (latest definition) | `CURRENT_DATE` → | `NOW()` → |
|-----|--------------------------|-------------------|-----------|
| `update_user_streak` | `20260323000005_streak_freeze_and_milestones.sql` | `app_current_date()` | — |
| `get_daily_quest_progress` | `20260323000002_update_quest_types.sql` | `app_current_date()` | `app_now()` |
| `claim_daily_bonus` | `20260322000003_daily_quest_engine.sql` | `app_current_date()` | — |
| `complete_daily_review` | `20260203000001_add_daily_review_sessions.sql` | `app_current_date()` | — |
| `complete_vocabulary_session` | `20260317000001_fix_session_sm2_interval_growth.sql` | — | `app_now()` |
| `get_quest_completion_stats` | `20260323000004_quest_admin_stats_rpc.sql` | `app_current_date()` | — |
| `get_words_due_for_review` | `20260131000010_create_functions.sql` | — | `app_now()` |
| `process_weekly_league_reset` | `20260218000001_league_school_based_reset.sql` | — | `app_now()` |

**Not replaced:**
- `DEFAULT NOW()` on column definitions (`created_at`, `updated_at`) — real time for audit trail
- `updated_at = NOW()` in UPDATE statements — real time for data integrity
- `NOW()` in `award_xp_transaction`, `spend_coins_transaction`, `award_coins_transaction` — transaction timestamps should be real

Each RPC is `CREATE OR REPLACE`'d in a single migration file. Functions whose return type hasn't changed can be replaced directly. Functions that have `RETURNS TABLE` with the same columns use `CREATE OR REPLACE`.

### Flutter — AppClock Utility

New file: `lib/core/utils/app_clock.dart`

```dart
class AppClock {
  static int _offsetDays = 0;

  /// Set the debug offset (called once from app init with SystemSettings value)
  static void setOffset(int days) => _offsetDays = days;

  /// Returns DateTime.now() shifted by offset days
  static DateTime now() => DateTime.now().add(Duration(days: _offsetDays));

  /// Returns today at midnight, shifted by offset
  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}
```

### Flutter — AppClock Initialization

When `SystemSettings` loads (via `systemSettingsProvider`), call `AppClock.setOffset(settings.debugDateOffset)`. This happens once at app start and whenever settings are refreshed.

### Flutter — DateTime.now() Replacements

Business logic usages of `DateTime.now()` replaced with `AppClock.now()`:

| File | Usage | Replace with |
|------|-------|-------------|
| `lib/core/utils/sm2_algorithm.dart` | `calculateNextReview()` — `nextReviewAt`, `lastReviewedAt` | `AppClock.now()` |
| `lib/domain/entities/assignment.dart` | `isOverdue`, `isActive`, `isUpcoming` | `AppClock.now()` |
| `lib/domain/entities/student_assignment.dart` | Status getters, `daysRemaining` | `AppClock.now()` |
| `lib/domain/entities/vocabulary.dart` | `isDueForReview` | `AppClock.now()` |
| `lib/presentation/widgets/common/streak_status_dialog.dart` | Weekly calendar "today" calculation | `AppClock.now()` |
| `lib/presentation/widgets/home/daily_quest_list.dart` | `_buildDueText()` assignment days remaining | `AppClock.now()` |
| `lib/presentation/screens/vocabulary/vocabulary_screen.dart` | `_formatNextReview()` | `AppClock.now()` |

**Not replaced** (real wall-clock time needed):
- `DateTime.now()` in `UserModel.toUpdateJson()` — real timestamp for DB writes
- `DateTime.now()` in `ContentBlock.empty()` — initialization timestamp
- `DateTime.now()` in cache staleness checks (`book_cache_store.dart`)
- `DateTime.now()` in session duration tracking
- `DateTime.now()` in `save_reading_progress_usecase.dart` — real progress timestamp

### SystemSettings Entity + Model

Add `debugDateOffset` (int, default 0) to:
- `lib/domain/entities/system_settings.dart` — field + constructor + props
- `lib/data/models/settings/system_settings_model.dart` — `fromMap`, `defaults`, `toEntity`, `fromEntity`

---

## Files

### New Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260323000006_debug_time_offset.sql` | Helper functions, setting, all RPC replacements |
| `lib/core/utils/app_clock.dart` | Flutter clock utility |

### Modified Files

| File | Change |
|------|--------|
| `lib/domain/entities/system_settings.dart` | Add `debugDateOffset` field |
| `lib/data/models/settings/system_settings_model.dart` | Parse `debug_date_offset` |
| `lib/core/utils/sm2_algorithm.dart` | `DateTime.now()` → `AppClock.now()` |
| `lib/domain/entities/assignment.dart` | `DateTime.now()` → `AppClock.now()` |
| `lib/domain/entities/student_assignment.dart` | `DateTime.now()` → `AppClock.now()` |
| `lib/domain/entities/vocabulary.dart` | `DateTime.now()` → `AppClock.now()` |
| `lib/presentation/widgets/common/streak_status_dialog.dart` | `DateTime.now()` → `AppClock.now()` |
| `lib/presentation/widgets/home/daily_quest_list.dart` | `DateTime.now()` → `AppClock.now()` |
| `lib/presentation/screens/vocabulary/vocabulary_screen.dart` | `DateTime.now()` → `AppClock.now()` |
| App initialization (provider or main) | Call `AppClock.setOffset()` from settings |

### No Changes

- Admin panel (setting auto-renders)
- Edge functions (only use timestamps for `updated_at` — real time)
- Main app quest/streak/review RPCs remain unchanged in Flutter code (they call RPCs which handle time server-side)

---

## Out of Scope

- Hour-level offset precision
- Per-user offset (global only)
- Absolute date override (use offset instead)
- UI indicator showing "debug mode active" (nice-to-have, add later)
- Automated time-travel test suite
