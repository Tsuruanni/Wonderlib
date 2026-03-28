# Streak System

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Security | `update_user_streak` RPC has no `auth.uid()` check — any authenticated user can update another user's streak | Critical | Fixed |
| 2 | Dead Code | Edge Function `supabase/functions/check-streak/index.ts` is unused (app calls SQL RPC directly); also holds `SUPABASE_SERVICE_ROLE_KEY` | High | Fixed |
| 3 | Edge Case | `StreakResult.hasEvent` hard-codes `previousStreak >= 3` but admin can set `notifStreakBrokenMin` to a different value, causing dialog suppression mismatch | Medium | Fixed |
| 4 | Architecture | `loginDatesProvider` calls `Supabase.instance.client` directly, bypassing Repository layer | Medium | Fixed |
| 5 | Idempotency | Milestone XP `award_xp_transaction` passes `source_id = NULL` — deduplication depends on whether `xp_logs` UNIQUE constraint handles NULLs | Medium | Fixed |
| 6 | Stale Comment | `addXP()` lines 261-265 comment says server RPCs "already call PERFORM update_user_streak()" — this was removed in migration `_010` | Low | Fixed |
| 7 | Config | Milestone XP values (7d=50, 14d=100, 30d=200, 60d=400, 100d=1000) are hard-coded in SQL, not admin-configurable via `system_settings` | Low | Fixed |
| 8 | Config | No milestone defined for streaks beyond 100 days (CASE returns 0 for day 101+) | Low | Fixed |
| 9 | Code Quality | Redundant `Container` wrapper around Close button `Text` in `StreakStatusDialog` (line 198) | Low | Fixed |

### Checklist Result

- **Architecture Compliance:** 1 issue — `loginDatesProvider` bypasses repository layer (#4)
- **Code Quality:** PASS (minor: redundant Container #9)
- **Dead Code:** 1 issue — unused Edge Function (#2), stale comment (#6)
- **Database & Security:** 1 CRITICAL — missing auth check on `update_user_streak` (#1); 1 idempotency concern (#5)
- **Edge Cases & UX:** 1 issue — `hasEvent` hard-coded threshold (#3)
- **Performance:** PASS
- **Cross-System Integrity:** PASS — streak correctly updates on app open only; coins/XP/badges all trigger atomically

---

## Overview

The Streak System tracks consecutive daily app usage. Students earn streak milestones with XP bonuses and can purchase streak freezes (with coins) to protect their streak during missed days. The system is **login-based** — streak updates happen once per app open, not per activity. Admin can configure freeze price, max freeze count, and notification thresholds via `system_settings`.

## Data Model

### Tables

**`profiles`** (streak columns on existing table):
| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `current_streak` | INTEGER | 0 | Active streak day count |
| `longest_streak` | INTEGER | 0 | All-time record |
| `last_activity_date` | DATE | NULL | Last day streak was evaluated |
| `streak_freeze_count` | INTEGER | 0 | Purchased freezes available |

**`daily_logins`** (calendar visualization):
| Column | Type | Purpose |
|--------|------|---------|
| `user_id` | UUID | FK → profiles |
| `login_date` | DATE | Calendar day |
| `is_freeze` | BOOLEAN | `true` = gap covered by freeze, `false` = actual login |
| PRIMARY KEY | `(user_id, login_date)` | Composite, prevents duplicates |

RLS: SELECT only (`user_id = auth.uid()`). Writes happen exclusively via `SECURITY DEFINER` RPCs.

**`system_settings`** (streak-related keys):
| Key | Default | Category | Purpose |
|-----|---------|----------|---------|
| `streak_freeze_price` | 50 | progression | Coin cost per freeze |
| `streak_freeze_max` | 2 | progression | Max freeze inventory |
| `notif_streak_extended` | true | notification | Show streak extended dialog |
| `notif_streak_broken` | true | notification | Show streak broken dialog |
| `notif_streak_broken_min` | 3 | notification | Min previous streak to show broken dialog |
| `notif_milestone` | true | notification | Show milestone dialog |
| `notif_freeze_saved` | true | notification | Show freeze-saved dialog |

### Key Relationships

```
profiles (streak columns)
    ↑ written by update_user_streak RPC
    ↑ written by buy_streak_freeze RPC

daily_logins
    ↑ written by update_user_streak RPC (login + freeze gap days)
    ↓ read by loginDatesProvider (weekly calendar)

system_settings
    ↓ read by SystemSettings entity (freeze price/max, notification flags)
```

## Surfaces

### Admin

- **System Settings editor** — can toggle notification flags (`notif_streak_extended`, `notif_streak_broken`, `notif_freeze_saved`, `notif_milestone`) and set `notif_streak_broken_min` threshold
- **Notification Gallery** — preview of streak notification types (extended, broken, milestone, freeze-saved)
- **Badge editor** — `streak_days` condition type available for badge creation (Turkish label: "Ardışık Aktif Gün")
- **Note:** `streak_freeze_price` and `streak_freeze_max` are seeded in migrations but have no dedicated admin UI — editable only via raw settings editor

### Student

**App Open Flow:**
1. User opens app → `UserController._updateStreakIfNeeded()` compares `lastActivityDate` to today
2. If already today → skip (idempotent, no redundant RPC)
3. If first open of the day → calls `update_user_streak` RPC
4. RPC evaluates gap, applies freezes if available, returns `StreakResult`
5. `LevelUpCelebrationListener` shows appropriate dialog (milestone > freeze-saved > broken > extended)

**Streak Status Dialog** (tap fire icon in navbar):
- Shows current streak count with fire icon
- 7-day weekly calendar (Mon–Sun) with color-coded days:
  - Orange fire = login day
  - Blue snowflake = freeze-covered day
  - Grey = missed or future day
- Longest streak display
- Freeze inventory (`X/Y`)
- Buy Freeze button (disabled if insufficient coins or max reached)

**Streak Event Dialogs** (auto-shown on app open):
- **Milestone** — "{N}-Day Streak! +{XP} XP earned!" (orange, fire icon)
- **Freeze Saved** — "Streak Freeze Saved You!" with remaining freeze count (blue, snowflake icon)
- **Streak Broken** — tiered messages by previous streak length:
  - ≤6 days: "Welcome Back! Start a new streak today."
  - 7–9 days: "Your {N}-day streak ended. You can build it again!"
  - 10–20 days: "Your {N}-day streak was broken. Don't give up!"
  - 21+ days: "Your {N}-day streak was broken. That was impressive — you can do it again!"
  - If partial freezes consumed: appends "Your {N} freeze(s) covered {N} day(s), but you were away too long."
- **Streak Extended** — "Day {N}!" with rotating subtitles ("Keep it up!", "You're on fire!", etc.)
  - Day 1 special: "Day 1! Let's go! Your learning streak starts today!"

### Teacher

- Streak stats visible per student (via `profiles.current_streak`, `longest_streak`)
- No teacher-specific streak management actions

## Business Rules

1. **Login-based streak** — streak increments once per calendar day on first app open. Activity completion does NOT update streak (removed in migration `_010`).
2. **Same-day idempotency** — if `last_activity_date == today`, RPC returns current streak with no changes. Client also guards this check before calling RPC.
3. **Freeze absorption** — if days missed ≤ freeze count: all gap days consumed, streak continues. If days missed > freeze count: all freezes consumed, streak breaks anyway (partial freeze does not save streak).
4. **Freeze gap recording** — absorbed gap days are inserted into `daily_logins` with `is_freeze = true` for calendar visualization.
5. **Milestone XP** — awarded at specific streak days, configurable via `system_settings` key `streak_milestones` (default: 7→50, 14→100, 30→200, 60→400, 100→1000 XP). Beyond defined milestones, repeating milestones award XP every `streak_milestone_repeat_interval` days (default: every 100 days, 1000 XP).
6. **Milestone XP is atomic** — `award_xp_transaction` is called within the same transaction as the profile update. Failure rolls back both.
7. **Streak freeze purchase** — costs `streak_freeze_price` coins (default 50). Max inventory: `streak_freeze_max` (default 2). Uses `spend_coins_transaction` for atomic coin deduction.
8. **Notification gating** — each dialog type is independently toggleable via `system_settings`. Broken-streak dialog has additional threshold: only shown if `previousStreak >= notifStreakBrokenMin` (default 3).
9. **Badge integration** — after streak update, `checkAndAwardBadgesUseCase` is called. `streak_days` is an available badge condition type.
10. **`app_current_date()` wrapper** — all date logic uses this function (respects `debug_date_offset` system setting for testing).
11. **Row-level locking** — `SELECT ... FOR UPDATE` on `profiles` prevents race conditions on concurrent streak updates.
12. **Repeating milestones** — after the last defined milestone (default day 100), XP is awarded every `streak_milestone_repeat_interval` days (default 100). Day 200, 300, etc. each award `streak_milestone_repeat_xp` (default 1000 XP). Set interval to 0 to disable.

## Cross-System Interactions

### Streak → XP System
```
Milestone hit (configurable days, default 7/14/30/60/100 + every 100 after)
  → award_xp_transaction(p_user_id, xp, 'streak_milestone', 'day_N', description)
  → XP added to profiles.xp
  → coins added 1:1 (XP = coins rule)
```

### Streak → Badge System
```
Streak updated
  → UserController.updateStreak() calls checkAndAwardBadgesUseCase
  → badge engine evaluates streak_days conditions
```

### Streak → Coin Economy
```
Buy freeze → spend_coins_transaction('streak_freeze', price)
  → profiles.coins -= streak_freeze_price
  → coin_logs INSERT for audit trail
```

### Streak → Daily Quest
```
Streak does NOT directly affect daily quest progress.
Quest progress is tracked implicitly via activity logs.
```

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| First-ever app open (no `last_activity_date`) | Streak = 1, `streak_extended = true`, Day 1 dialog |
| Same-day re-open | No RPC call (client guard), no dialog |
| 1 day missed, 1 freeze available | Freeze consumed, streak continues, freeze-saved dialog |
| 3 days missed, 2 freezes available | Both freezes consumed, streak breaks, broken dialog with partial-freeze message |
| 3 days missed, 3+ freezes available | All 3 gap days frozen, streak continues |
| Buy freeze at max inventory | "Max freezes reached" shown, buy button hidden |
| Buy freeze with insufficient coins | Buy button disabled (grey) |
| Streak = 0, then broken | `previousStreak = 0`, no broken dialog (threshold requires ≥3 by default) |
| Exactly day 7/14/30/60/100 | Milestone XP awarded, milestone dialog shown |
| Day 101+ | No milestone unless repeating interval hit (default: day 200, 300, ...) |
| Day 200 (repeat milestone) | `streak_milestone_repeat_xp` awarded (default 1000 XP) |
| `notifStreakBrokenMin` set to 1 in admin | Works correctly — provider gates on settings, no hard-coded threshold |

## Test Scenarios

- [ ] **Happy path**: Open app on consecutive days, verify streak increments and "Day N!" dialog appears
- [ ] **Streak break**: Skip 2+ days, open app, verify broken-streak dialog with correct previous streak count
- [ ] **Freeze save**: Buy a freeze, skip 1 day, open app → verify "Streak Freeze Saved You!" dialog and streak continues
- [ ] **Partial freeze**: Have 1 freeze, skip 3 days → verify freeze consumed but streak breaks, dialog shows partial message
- [ ] **Buy freeze**: Tap fire icon → streak dialog → buy freeze → verify coin deduction and freeze count increment
- [ ] **Insufficient coins**: Try to buy freeze with <50 coins → button should be disabled
- [ ] **Max freezes**: Buy max freezes → "Max freezes reached" shown, buy button hidden
- [ ] **Milestone XP**: Reach day 7 → verify +50 XP awarded and milestone dialog
- [ ] **Same-day idempotency**: Open app twice on same day → second open shows no streak dialog
- [ ] **Calendar display**: Check streak status dialog → weekly calendar shows correct login (orange) and freeze (blue) days
- [ ] **Badge trigger**: Set up a streak_days badge for 7 days → reach day 7 → badge awarded
- [ ] **First-ever login**: Fresh user opens app → "Day 1! Let's go!" dialog

## Key Files

### Domain Layer
- `lib/domain/entities/streak_result.dart` — `StreakResult`, `BuyFreezeResult` entities
- `lib/domain/usecases/user/update_streak_usecase.dart` — `UpdateStreakUseCase`
- `lib/domain/usecases/user/buy_streak_freeze_usecase.dart` — `BuyStreakFreezeUseCase`

### Data Layer
- `lib/data/repositories/supabase/supabase_user_repository.dart` (lines 96–154) — RPC calls + JSON mapping

### Presentation Layer
- `lib/presentation/providers/user_provider.dart` — `UserController` (streak logic at lines 194–313), `loginDatesProvider`, `streakEventProvider`
- `lib/presentation/widgets/common/streak_event_dialog.dart` — milestone/freeze/broken/extended dialogs
- `lib/presentation/widgets/common/streak_status_dialog.dart` — streak status with calendar + freeze purchase
- `lib/presentation/widgets/common/top_navbar.dart` — fire icon with streak count
- `lib/presentation/widgets/common/level_up_celebration.dart` — listener that shows streak event dialogs

### Database
- `supabase/migrations/20260328000007_streak_milestone_configurable.sql` — canonical `update_user_streak` RPC (configurable milestones)
- `supabase/migrations/20260323000005_streak_freeze_and_milestones.sql` — `buy_streak_freeze` RPC, `streak_freeze_count` column, system settings seed
- `supabase/migrations/20260323000008_daily_logins.sql` — `daily_logins` table + RLS

## Known Issues & Tech Debt

None — all audit findings have been resolved.
