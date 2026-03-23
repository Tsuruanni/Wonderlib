# Streak Freeze & Milestones — Design Spec

**Date:** 2026-03-23
**Scope:** Streak freeze purchase/consumption system + streak milestone bonus XP + streak event notifications.

---

## Problem

The streak system works correctly but has three gaps:

1. **No protection:** Missing a single day resets the streak with no recourse. This is punishing for K-12 students (weekends, holidays, sick days).
2. **No milestone rewards:** The `check-streak` Edge Function has milestone bonus XP (7/14/30/60/100 days) but is never called. Streaks increment silently with no celebration.
3. **No event notifications:** The RPC returns `streak_broken` and `streak_extended` signals but Flutter discards them. Users get no feedback on streak state changes.

---

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Freeze purchase | Coins (50 coins, configurable via admin settings) | Creates a coin sink, simple, no streak-length coupling |
| Max capacity | 2 (configurable via admin settings) | Covers a weekend, matches Duolingo's proven model |
| Freeze consumption | In `update_user_streak` RPC with multi-day backfill | No cron needed. Freezes consumed when user returns. Handles multi-day gaps correctly. |
| Milestone amounts | Hardcoded in RPC: 7/14/30/60/100 days → 50/100/200/400/1000 XP + equal coins | Matches existing `check-streak` Edge Function values. `award_xp_transaction` awards 1:1 coins — this is consistent with all other XP sources. |
| Freeze storage | Counter column on `profiles` (not a separate table) | Freezes are fungible — no purchase history, no expiry, no individual tracking needed. |
| Settings location | `system_settings` table, `progression` category | Admin panel auto-renders. No admin UI changes needed. |
| Where to buy | Streak dialog (fire icon tap in top navbar) | Keeps all streak info in one place. No new screens. |
| Event notifications | Dialogs for all events: milestone hit, freeze saved streak, streak broken | Loss aversion + celebration. Both drive engagement. |

---

## Design

### Database Changes

#### Modified: `profiles` table

```sql
ALTER TABLE profiles ADD COLUMN streak_freeze_count INTEGER DEFAULT 0;
-- No CHECK constraint — max enforced at runtime via system_settings
```

#### New settings in `system_settings`

```sql
INSERT INTO system_settings (key, value, category, description) VALUES
  ('streak_freeze_price', '50', 'progression', 'Coin cost to buy one streak freeze'),
  ('streak_freeze_max', '2', 'progression', 'Maximum streak freezes a user can hold');
```

These appear automatically in the admin panel under the `progression` category.

#### Modified: `update_user_streak` RPC

Current signature returns `(new_streak, longest_streak, streak_broken, streak_extended)`.

New signature:

```sql
RETURNS TABLE(
  new_streak INT,
  longest_streak INT,
  streak_broken BOOLEAN,
  streak_extended BOOLEAN,
  freeze_used BOOLEAN,
  freezes_consumed INT,
  freezes_remaining INT,
  milestone_bonus_xp INT
)
```

New logic (replacing the existing gap >= 2 days branch). Note: the `last_activity_date IS NULL` case (first-time user) continues to be handled separately — `new_streak = 1`, no freezes consumed, same as current behavior.

```
-- Only entered when last_activity_date is NOT NULL and gap >= 2 days
days_missed = (v_today - last_activity_date) - 1

if days_missed <= streak_freeze_count:
    -- All missed days covered by freezes
    UPDATE profiles SET streak_freeze_count = streak_freeze_count - days_missed
    new_streak = current_streak + 1  (today counts as activity)
    freeze_used = true
    freezes_consumed = days_missed
    streak_extended = true
elif streak_freeze_count > 0:
    -- Partial coverage: some freezes but not enough
    freezes_consumed = streak_freeze_count
    UPDATE profiles SET streak_freeze_count = 0
    new_streak = 1  (streak broken despite partial freeze)
    streak_broken = true
    freeze_used = true
else:
    -- No freezes (current behavior)
    new_streak = 1
    streak_broken = true
    freeze_used = false
    freezes_consumed = 0
```

Milestone bonus logic (when `streak_extended = true`):

```
milestone_bonus_xp = CASE new_streak
    WHEN 7  THEN 50
    WHEN 14 THEN 100
    WHEN 30 THEN 200
    WHEN 60 THEN 400
    WHEN 100 THEN 1000
    ELSE 0
END

if milestone_bonus_xp > 0:
    PERFORM award_xp_transaction(p_user_id, milestone_bonus_xp, 'streak_milestone', NULL, 'Streak milestone: ' || new_streak || ' days')
```

`freezes_remaining` is read from profiles after all updates.

**Double-call idempotency note:** `complete_vocabulary_session` and `complete_daily_review` call `PERFORM update_user_streak()` server-side. Flutter's `UserController.addXP()` then calls `updateStreak()` again. The second call sees `last_activity_date = today` and returns `streak_extended = false` with `milestone_bonus_xp = 0` — the milestone award is idempotent because it only fires when `streak_extended = true`. This means milestone XP is awarded during the first (server-side) call, but the milestone event dialog is triggered from the Flutter-side call's result. Since the Flutter-side call returns `streak_extended = false`, the milestone dialog will NOT fire for milestones that happen during vocab sessions or daily reviews.

**Accepted limitation:** Milestones triggered during server-side RPC calls award XP silently. The user sees the XP increase on profile refresh but does not get a celebration dialog. This is acceptable because (a) milestones are rare events, (b) the XP still lands, and (c) fixing this would require restructuring the double-call pattern which is out of scope.

#### New RPC: `buy_streak_freeze`

```sql
CREATE FUNCTION buy_streak_freeze(p_user_id UUID)
RETURNS TABLE(success BOOLEAN, freeze_count INT, coins_remaining INT)
LANGUAGE plpgsql SECURITY DEFINER
```

Logic:
1. Auth check: `auth.uid() = p_user_id`
2. Read `streak_freeze_max` and `streak_freeze_price` from `system_settings`
3. Lock profiles row `FOR UPDATE`
4. Check `streak_freeze_count < max` → else raise 'max_freezes_reached'
5. Call `PERFORM spend_coins_transaction(p_user_id, price, 'streak_freeze', NULL, 'Purchased streak freeze')` — this atomically deducts coins, prevents negative balance, and logs to `coin_logs` with correct `balance_after`
6. `UPDATE profiles SET streak_freeze_count = streak_freeze_count + 1`
7. Return `(true, new_freeze_count, new_coins)`

Uses existing `spend_coins_transaction` instead of manual coin deduction to ensure consistency with `coin_logs.balance_after` NOT NULL constraint and future coin logic changes.

### Flutter — Domain Layer

#### New entity: `StreakResult`

```
lib/domain/entities/streak_result.dart

StreakResult(
  newStreak: int,
  longestStreak: int,
  streakBroken: bool,
  streakExtended: bool,
  freezeUsed: bool,
  freezesConsumed: int,
  freezesRemaining: int,
  milestoneBonusXp: int,
)
```

#### Modified entity: `User`

Add field: `streakFreezeCount` (int, default 0). Add to `Equatable` props list.

#### Modified: `UserRepository`

- `updateStreak(userId)` return type: `Either<Failure, User>` → `Either<Failure, StreakResult>`
- New: `buyStreakFreeze(userId)` → `Either<Failure, BuyFreezeResult>`

`BuyFreezeResult` is a simple class: `{freezeCount: int, coinsRemaining: int}`.

#### Modified: `SystemSettings` entity + model

Add fields: `streakFreezePrice` (int), `streakFreezeMax` (int).

#### Use cases

- `UpdateStreakUseCase` — return type changes to `StreakResult`
- New: `BuyStreakFreezeUseCase`

### Flutter — Data Layer

#### `UserModel`

Map `streak_freeze_count` from JSON.

#### `SupabaseUserRepository`

- `updateStreak()`: Parse RPC result into `StreakResult` entity inline (no separate model class — the RPC returns a single row with simple fields, parsed directly in the repository). Currently discards result and re-fetches profile.
- `buyStreakFreeze()`: Call `buy_streak_freeze` RPC, parse inline into `BuyFreezeResult` (same — simple enough for inline parsing).

#### `SystemSettingsModel`

Parse `streak_freeze_price` and `streak_freeze_max` from settings map.

### Flutter — Presentation Layer

#### `streakEventProvider`

```dart
final streakEventProvider = StateProvider<StreakResult?>((_) => null);
```

Set by `UserController.updateStreak()`. Reset to null after dialog is shown.

#### Modified: `UserController.updateStreak()`

1. Call `UpdateStreakUseCase` → get `StreakResult`
2. Re-fetch profile (updates `streakFreezeCount`, `currentStreak` in state)
3. If result has any event (milestone, freeze used, streak broken) → set `streakEventProvider`

#### New: `buyStreakFreeze()` on `UserController`

Calls `BuyStreakFreezeUseCase`, re-fetches profile on success.

#### Modified: `streak_status_dialog.dart`

Add below 7-day calendar:
- Freeze section: snowflake icon + "Streak Freezes: N/M"
- Buy button: "Buy Freeze (50 coins)" — disabled if at max or insufficient coins
- Button calls `UserController.buyStreakFreeze()`, shows SnackBar on success/failure

Freeze count and price read from user state and `SystemSettings`.

#### New: `streak_event_dialog.dart`

Three dialog variants triggered by `streakEventProvider`:

| Event | Content |
|-------|---------|
| `milestoneBonusXp > 0` | Fire animation + "N-Day Streak! +X XP" |
| `freezeUsed && !streakBroken` | Snowflake icon + "Streak Freeze saved your N-day streak! X freezes left." |
| `streakBroken` | Broken fire icon + "Your streak was broken." If `freezesConsumed > 0`: "Your N freezes covered N days, but you were away too long." |

Priority: milestone > freeze-saved > streak-broken (one per session).

Triggered from `home_screen.dart` via `ref.listen(streakEventProvider)`.

#### Provider registration

- `usecase_providers.dart`: Register `BuyStreakFreezeUseCase`

### Dead Code Cleanup

| File | Action |
|------|--------|
| `lib/core/services/edge_function_service.dart` | Delete `checkStreak()` method and old `StreakResult` class (must happen before or with new `StreakResult` entity creation to avoid name collision) |
| `lib/core/constants/app_constants.dart` | Delete `streakResetHours = 48` |
| `supabase/functions/check-streak/index.ts` | Leave as-is (dormant). Milestones now in RPC. |

---

## Files

### New Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260323000005_streak_freeze_and_milestones.sql` | Column, settings, modified RPC, new RPC |
| `lib/domain/entities/streak_result.dart` | `StreakResult` entity |
| `lib/domain/usecases/user/buy_streak_freeze_usecase.dart` | Buy freeze use case |
| `lib/presentation/widgets/common/streak_event_dialog.dart` | Milestone / freeze-saved / streak-broken dialogs |

### Modified Files

| File | Change |
|------|--------|
| `lib/domain/entities/user.dart` | Add `streakFreezeCount` |
| `lib/data/models/user/user_model.dart` | Map `streak_freeze_count` |
| `lib/domain/entities/system_settings.dart` | Add `streakFreezePrice`, `streakFreezeMax` |
| `lib/data/models/settings/system_settings_model.dart` | Parse new settings |
| `lib/domain/repositories/user_repository.dart` | `updateStreak` returns `StreakResult`, add `buyStreakFreeze` |
| `lib/data/repositories/supabase/supabase_user_repository.dart` | Parse RPC result, implement `buyStreakFreeze` |
| `lib/domain/usecases/user/update_streak_usecase.dart` | Return type → `StreakResult` |
| `lib/presentation/providers/user_provider.dart` | `streakEventProvider`, updated `updateStreak()`, new `buyStreakFreeze()` |
| `lib/presentation/providers/usecase_providers.dart` | Register `BuyStreakFreezeUseCase` |
| `lib/presentation/widgets/common/streak_status_dialog.dart` | Freeze section + buy button |
| `lib/presentation/screens/home/home_screen.dart` | `ref.listen(streakEventProvider)` → show event dialogs |
| `lib/core/services/edge_function_service.dart` | Delete `checkStreak()` and old `StreakResult` |
| `lib/core/constants/app_constants.dart` | Delete `streakResetHours` |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `buyStreakFreeze` |

### No Changes

- `check-streak` Edge Function (left dormant)
- Admin panel (settings auto-render from `system_settings`)
- Daily quest system (streaks stay independent)
- `reader_provider.dart` streak trigger path (calls same `updateStreak`, gets new return type for free)

---

## Out of Scope

- Streak repair after break (Duolingo Super feature — add later if needed)
- Streak Society tiers / cosmetic rewards
- Streak-based daily quest type
- Wiring up `max_streak_multiplier` / `streak_bonus_increment` / `xp_streak_bonus_day` (existing dead settings — separate cleanup)
- Push notifications ("Don't lose your streak!")
- Timezone alignment between streak and quest systems
