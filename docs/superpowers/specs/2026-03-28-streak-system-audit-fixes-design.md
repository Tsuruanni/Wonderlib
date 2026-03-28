# Streak System Audit Fixes

**Date:** 2026-03-28
**Scope:** Fix all 7 findings from Feature #10 (Streak System) audit
**Approach:** Single PR, commits grouped by severity (security > architecture > cleanup)

---

## Fixes

### Fix #1 — Auth check for `update_user_streak` RPC [CRITICAL]

**Problem:** `update_user_streak(p_user_id UUID)` is `SECURITY DEFINER` with no `auth.uid()` check. Any authenticated user can update any other user's streak.

**Solution:** New migration `20260328000001_streak_audit_fixes.sql` — `CREATE OR REPLACE FUNCTION update_user_streak` with auth guard added at the top of the function body:

```sql
IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'unauthorized';
END IF;
```

Same pattern as `buy_streak_freeze` which already has this check.

### Fix #5 — Milestone XP idempotency [MEDIUM]

**Problem:** `award_xp_transaction` is called with `source_id = NULL` for milestone XP. If `xp_logs` UNIQUE constraint doesn't handle NULLs, duplicate milestone XP can be awarded.

**Solution:** In the same migration, change the `award_xp_transaction` call to use a deterministic source_id:

```sql
-- Before
PERFORM award_xp_transaction(p_user_id, v_milestone_xp, 'streak_milestone', NULL, 'Streak milestone: ' || v_new_streak || ' days');

-- After
PERFORM award_xp_transaction(p_user_id, v_milestone_xp, 'streak_milestone', 'day_' || v_new_streak, 'Streak milestone: ' || v_new_streak || ' days');
```

This makes `(user_id, 'streak_milestone', 'day_7')` a unique key, preventing double awards.

### Fix #3 — `hasEvent` hard-coded threshold [MEDIUM]

**Problem:** `StreakResult.hasEvent` getter hard-codes `previousStreak >= 3` for broken-streak dialog gating. But admin can set `notifStreakBrokenMin` to any value. If set to 1 or 2, the provider fires the event but `hasEvent` returns false, suppressing the dialog.

**Solution:** Remove `hasEvent` getter from `StreakResult` entity. The provider's `shouldShow` logic in `UserController.updateStreak()` already correctly reads from `SystemSettings.notifStreakBrokenMin`. Update `LevelUpCelebrationListener` to check `next != null` instead of `next != null && next.hasEvent`.

**Files:**
- `lib/domain/entities/streak_result.dart` — remove `hasEvent` getter
- `lib/presentation/widgets/common/level_up_celebration.dart` — change `next.hasEvent` to `next != null`

### Fix #4 — `loginDatesProvider` repository bypass [MEDIUM]

**Problem:** `loginDatesProvider` in `user_provider.dart` calls `Supabase.instance.client.from(DbTables.dailyLogins)` directly, bypassing the Repository layer. This violates the clean architecture rule and makes the provider untestable.

**Solution:** Follow the codebase's standard pattern (every FutureProvider uses a UseCase):

1. Add `getLoginDates(String userId, DateTime from)` to `UserRepository` interface — returns `Future<Either<Failure, Map<DateTime, bool>>>`
2. Implement in `SupabaseUserRepository` — move query logic from `loginDatesProvider`
3. Create `GetLoginDatesUseCase` with `GetLoginDatesParams(userId, from)` in `lib/domain/usecases/user/`
4. Register `getLoginDatesUseCaseProvider` in `usecase_providers.dart`
5. Refactor `loginDatesProvider` to use the use case via standard fold pattern

**Files:**
- `lib/domain/repositories/user_repository.dart` — add method signature
- `lib/domain/usecases/user/get_login_dates_usecase.dart` — NEW UseCase + Params
- `lib/data/repositories/supabase/supabase_user_repository.dart` — implement query
- `lib/presentation/providers/usecase_providers.dart` — register use case provider
- `lib/presentation/providers/user_provider.dart` — refactor `loginDatesProvider`

### Fix #2 — Delete dead Edge Function [HIGH]

**Problem:** `supabase/functions/check-streak/index.ts` is a complete but unused Edge Function that duplicates the SQL RPC logic. It also contains `SUPABASE_SERVICE_ROLE_KEY` usage.

**Solution:** Delete `supabase/functions/check-streak/` directory entirely.

### Fix #6 — Stale comment in `addXP()` [LOW]

**Problem:** Lines 261-265 in `user_provider.dart` say "Server-side RPCs (complete_daily_review, complete_vocabulary_session) already call PERFORM update_user_streak() internally." This was removed in migration `_010`.

**Solution:** Update comment to reflect current login-based model:

```dart
// Note: NOT calling updateStreak() here.
// Streak is login-based — updated once per day on app open via _updateStreakIfNeeded.
```

### Fix #7 — Redundant Container wrapper [LOW]

**Problem:** `StreakStatusDialog` line 198 wraps the Close button's `Text` in an unnecessary `Container` with no decoration or padding.

**Solution:** Remove the `Container` wrapper, keep the `Text` widget directly as the `child` of `ElevatedButton`.

---

## Migration File

Single new migration: `20260328000001_streak_audit_fixes.sql`

Contains:
- `CREATE OR REPLACE FUNCTION update_user_streak` — full function redefinition with auth check (#1) and deterministic milestone source_id (#5)

---

## Spec Update

After fixes, update `docs/specs/10-streak-system.md` audit table statuses from `TODO` to `Fixed`.

---

## Files Changed

| File | Change |
|------|--------|
| `supabase/migrations/20260328000001_streak_audit_fixes.sql` | NEW — auth check + idempotency fix |
| `lib/domain/entities/streak_result.dart` | Remove `hasEvent` getter |
| `lib/domain/repositories/user_repository.dart` | Add `getLoginDates` method |
| `lib/domain/usecases/user/get_login_dates_usecase.dart` | NEW — UseCase + Params |
| `lib/data/repositories/supabase/supabase_user_repository.dart` | Implement `getLoginDates` |
| `lib/presentation/providers/usecase_providers.dart` | Register `getLoginDatesUseCaseProvider` |
| `lib/presentation/providers/user_provider.dart` | Refactor `loginDatesProvider`, fix stale comment |
| `lib/presentation/widgets/common/level_up_celebration.dart` | Update `hasEvent` check |
| `lib/presentation/widgets/common/streak_status_dialog.dart` | Remove redundant Container |
| `supabase/functions/check-streak/` | DELETE directory |
| `docs/specs/10-streak-system.md` | Update audit statuses to Fixed |
