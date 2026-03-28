# Streak System Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 7 audit findings from Feature #10 (Streak System) — security, architecture, and cleanup.

**Architecture:** SQL migration fixes auth check + idempotency in `update_user_streak` RPC. Dart-side fixes remove `hasEvent` hard-coded gate, route `loginDatesProvider` through the repository layer, and clean up dead code/comments.

**Tech Stack:** PostgreSQL (Supabase), Dart/Flutter, Riverpod

---

### Task 1: Security — Add auth check + idempotency fix to `update_user_streak` RPC

**Files:**
- Create: `supabase/migrations/20260328000001_streak_audit_fixes.sql`

**Context:** The canonical `update_user_streak` is in `supabase/migrations/20260323000011_streak_previous_streak.sql`. It's `SECURITY DEFINER` with no `auth.uid()` check. Also, milestone XP `award_xp_transaction` passes `NULL` as `source_id`, weakening idempotency.

- [ ] **Step 1: Create the migration file**

```sql
-- Streak audit fixes:
-- 1. Add auth.uid() check to update_user_streak (security)
-- 2. Use deterministic source_id for milestone XP idempotency

DROP FUNCTION IF EXISTS update_user_streak(UUID);
CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID)
RETURNS TABLE(
    new_streak INTEGER,
    longest_streak INTEGER,
    streak_broken BOOLEAN,
    streak_extended BOOLEAN,
    freeze_used BOOLEAN,
    freezes_consumed INTEGER,
    freezes_remaining INTEGER,
    milestone_bonus_xp INTEGER,
    previous_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_activity DATE;
    v_current_streak INTEGER;
    v_longest_streak INTEGER;
    v_freeze_count INTEGER;
    v_today DATE := app_current_date();
    v_new_streak INTEGER;
    v_streak_broken BOOLEAN := FALSE;
    v_streak_extended BOOLEAN := FALSE;
    v_freeze_used BOOLEAN := FALSE;
    v_freezes_consumed INTEGER := 0;
    v_days_missed INTEGER;
    v_milestone_xp INTEGER := 0;
    i INTEGER;
BEGIN
    -- Auth check: prevent updating another user's streak
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    SELECT p.last_activity_date, p.current_streak, p.longest_streak, p.streak_freeze_count
    INTO v_last_activity, v_current_streak, v_longest_streak, v_freeze_count
    FROM profiles p
    WHERE p.id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    INSERT INTO daily_logins (user_id, login_date, is_freeze)
    VALUES (p_user_id, v_today, false)
    ON CONFLICT (user_id, login_date) DO UPDATE SET is_freeze = false;

    IF v_last_activity IS NULL THEN
        v_new_streak := 1;
        v_streak_extended := TRUE;
    ELSIF v_last_activity = v_today THEN
        v_new_streak := v_current_streak;
    ELSIF v_last_activity = v_today - 1 THEN
        v_new_streak := v_current_streak + 1;
        v_streak_extended := TRUE;
    ELSE
        v_days_missed := (v_today - v_last_activity) - 1;

        IF v_days_missed <= v_freeze_count THEN
            v_freeze_count := v_freeze_count - v_days_missed;
            v_new_streak := v_current_streak + 1;
            v_streak_extended := TRUE;
            v_freeze_used := TRUE;
            v_freezes_consumed := v_days_missed;

            FOR i IN 1..v_days_missed LOOP
                INSERT INTO daily_logins (user_id, login_date, is_freeze)
                VALUES (p_user_id, v_last_activity + i, true)
                ON CONFLICT (user_id, login_date) DO NOTHING;
            END LOOP;

        ELSIF v_freeze_count > 0 THEN
            v_freezes_consumed := v_freeze_count;
            v_freeze_count := 0;
            v_new_streak := 1;
            v_streak_broken := TRUE;
            v_freeze_used := TRUE;

            FOR i IN 1..v_freezes_consumed LOOP
                INSERT INTO daily_logins (user_id, login_date, is_freeze)
                VALUES (p_user_id, v_last_activity + i, true)
                ON CONFLICT (user_id, login_date) DO NOTHING;
            END LOOP;

        ELSE
            v_new_streak := 1;
            v_streak_broken := TRUE;
        END IF;
    END IF;

    IF v_new_streak > v_longest_streak THEN
        v_longest_streak := v_new_streak;
    END IF;

    IF v_streak_extended THEN
        v_milestone_xp := CASE v_new_streak
            WHEN 7   THEN 50
            WHEN 14  THEN 100
            WHEN 30  THEN 200
            WHEN 60  THEN 400
            WHEN 100 THEN 1000
            ELSE 0
        END;

        IF v_milestone_xp > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, v_milestone_xp, 'streak_milestone',
                'day_' || v_new_streak, 'Streak milestone: ' || v_new_streak || ' days'
            );
        END IF;
    END IF;

    UPDATE profiles
    SET current_streak = v_new_streak,
        longest_streak = v_longest_streak,
        last_activity_date = v_today,
        streak_freeze_count = v_freeze_count,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT v_new_streak, v_longest_streak, v_streak_broken, v_streak_extended,
                        v_freeze_used, v_freezes_consumed, v_freeze_count, v_milestone_xp,
                        v_current_streak;
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Migration listed as pending, no errors.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260328000001_streak_audit_fixes.sql
git commit -m "security: add auth check to update_user_streak + milestone idempotency fix (#10 audit fix 1,5)"
```

---

### Task 2: Remove `hasEvent` hard-coded threshold

**Files:**
- Modify: `lib/domain/entities/streak_result.dart:26-30` — remove `hasEvent` getter
- Modify: `lib/presentation/widgets/common/level_up_celebration.dart:69` — change `next.hasEvent` to `next != null`

**Context:** `hasEvent` hard-codes `previousStreak >= 3` but admin can set `notifStreakBrokenMin` to a different value. The provider's `shouldShow` logic in `UserController.updateStreak()` already correctly reads from `SystemSettings`, so this getter is a redundant (and wrong) gate.

- [ ] **Step 1: Remove `hasEvent` getter from `StreakResult`**

In `lib/domain/entities/streak_result.dart`, delete lines 26-30:
```dart
  /// Show event dialog? Streak extended always. Milestone and freeze always.
  /// Streak broken only if >= 3 days (default, overridable via settings).
  bool get hasEvent =>
      streakExtended ||
      milestoneBonusXp > 0 || freezeUsed || (streakBroken && previousStreak >= 3);
```

- [ ] **Step 2: Update `LevelUpCelebrationListener`**

In `lib/presentation/widgets/common/level_up_celebration.dart`, change line 69 from:
```dart
      if (next != null && next.hasEvent) {
```
to:
```dart
      if (next != null) {
```

This is safe because `UserController.updateStreak()` only sets `streakEventProvider` when `shouldShow` is true (lines 287-294 of `user_provider.dart`). If the provider is non-null, it should always be shown.

- [ ] **Step 3: Verify no other references to `hasEvent`**

Run: `grep -r "hasEvent" lib/`
Expected: No matches (only the two locations we just changed).

- [ ] **Step 4: Run analysis**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/streak_result.dart lib/presentation/widgets/common/level_up_celebration.dart
git commit -m "fix: remove hard-coded hasEvent threshold, rely on admin notifStreakBrokenMin (#10 audit fix 3)"
```

---

### Task 3: Route `loginDatesProvider` through Repository layer

**Files:**
- Modify: `lib/domain/repositories/user_repository.dart:27` — add method
- Create: `lib/domain/usecases/user/get_login_dates_usecase.dart` — new UseCase
- Modify: `lib/data/repositories/supabase/supabase_user_repository.dart` — implement method
- Modify: `lib/presentation/providers/usecase_providers.dart:96-97` — register provider
- Modify: `lib/presentation/providers/user_provider.dart:93-118` — refactor `loginDatesProvider`

**Context:** `loginDatesProvider` currently calls `Supabase.instance.client.from(DbTables.dailyLogins)` directly, violating the clean architecture rule. Every other FutureProvider in the codebase uses a UseCase.

- [ ] **Step 1: Add method to `UserRepository` interface**

In `lib/domain/repositories/user_repository.dart`, after the existing `getLast7DaysActivity` method (line 27), add:

```dart
  /// Get login dates for streak calendar (from daily_logins table)
  /// Returns map: date → is_freeze (true = freeze day, false = login day)
  Future<Either<Failure, Map<DateTime, bool>>> getLoginDates(String userId, DateTime from);
```

- [ ] **Step 2: Create `GetLoginDatesUseCase`**

Create `lib/domain/usecases/user/get_login_dates_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetLoginDatesParams {
  const GetLoginDatesParams({required this.userId, required this.from});
  final String userId;
  final DateTime from;
}

class GetLoginDatesUseCase implements UseCase<Map<DateTime, bool>, GetLoginDatesParams> {
  const GetLoginDatesUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, Map<DateTime, bool>>> call(GetLoginDatesParams params) {
    return _repository.getLoginDates(params.userId, params.from);
  }
}
```

- [ ] **Step 3: Implement in `SupabaseUserRepository`**

In `lib/data/repositories/supabase/supabase_user_repository.dart`, add after the `buyStreakFreeze` method (after line 154):

```dart
  @override
  Future<Either<Failure, Map<DateTime, bool>>> getLoginDates(String userId, DateTime from) async {
    try {
      final response = await _supabase
          .from(DbTables.dailyLogins)
          .select('login_date, is_freeze')
          .eq('user_id', userId)
          .gte('login_date', from.toIso8601String().split('T').first);

      final map = <DateTime, bool>{};
      for (final row in response as List) {
        final date = DateTime.parse(row['login_date'] as String);
        map[DateTime(date.year, date.month, date.day)] = row['is_freeze'] as bool? ?? false;
      }
      return Right(map);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 4: Register use case provider**

In `lib/presentation/providers/usecase_providers.dart`, add the import after line 97:

```dart
import '../../domain/usecases/user/get_login_dates_usecase.dart';
```

And add the provider after `buyStreakFreezeUseCaseProvider` (after line 492):

```dart
final getLoginDatesUseCaseProvider = Provider((ref) {
  return GetLoginDatesUseCase(ref.watch(userRepositoryProvider));
});
```

- [ ] **Step 5: Refactor `loginDatesProvider`**

In `lib/presentation/providers/user_provider.dart`, replace lines 93-118 (the entire `loginDatesProvider`) with:

```dart
/// Login/freeze dates for streak calendar (from daily_logins table)
/// Returns map: date → is_freeze (true = freeze day, false = login day)
final loginDatesProvider = FutureProvider<Map<DateTime, bool>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};

  final today = AppClock.today();
  final monday = today.subtract(Duration(days: today.weekday - 1));

  final useCase = ref.watch(getLoginDatesUseCaseProvider);
  final result = await useCase(GetLoginDatesParams(userId: userId, from: monday));
  return result.fold(
    (failure) => <DateTime, bool>{},
    (dates) => dates,
  );
});
```

Also add the import at the top of the file (with the other usecase imports):

```dart
import '../../domain/usecases/user/get_login_dates_usecase.dart';
```

And remove the now-unused `Supabase` import if it's only used by `loginDatesProvider` (check first — it may be used elsewhere in the file).

- [ ] **Step 6: Run analysis**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/user_repository.dart \
        lib/domain/usecases/user/get_login_dates_usecase.dart \
        lib/data/repositories/supabase/supabase_user_repository.dart \
        lib/presentation/providers/usecase_providers.dart \
        lib/presentation/providers/user_provider.dart
git commit -m "refactor: route loginDatesProvider through repository layer (#10 audit fix 4)"
```

---

### Task 4: Delete dead Edge Function

**Files:**
- Delete: `supabase/functions/check-streak/index.ts`

**Context:** This Edge Function duplicates the SQL RPC logic and is never called by the app. It also uses `SUPABASE_SERVICE_ROLE_KEY` which is a security concern.

- [ ] **Step 1: Verify no references to this function**

Run: `grep -r "check-streak" lib/ supabase/ packages/ --include="*.dart" --include="*.ts" --include="*.sql" --include="*.toml"`
Expected: Only the function itself and possibly `supabase/config.toml` (if it lists functions). No Dart code references it.

- [ ] **Step 2: Delete the function directory**

```bash
rm -rf supabase/functions/check-streak/
```

- [ ] **Step 3: Commit**

```bash
git add -A supabase/functions/check-streak/
git commit -m "cleanup: remove dead check-streak Edge Function (#10 audit fix 2)"
```

---

### Task 5: Fix stale comment + redundant Container

**Files:**
- Modify: `lib/presentation/providers/user_provider.dart:260-265` — fix stale comment
- Modify: `lib/presentation/widgets/common/streak_status_dialog.dart:198-206` — remove Container wrapper

- [ ] **Step 1: Fix stale comment in `addXP()`**

In `lib/presentation/providers/user_provider.dart`, replace lines 260-265:

```dart
    // Note: NOT calling updateStreak() here.
    // Server-side RPCs (complete_daily_review, complete_vocabulary_session)
    // already call PERFORM update_user_streak() internally.
    // The streak was already updated on app open via _updateStreakIfNeeded.
    // Calling it again would be idempotent but would suppress event dialogs
    // (second same-day call returns no events).
```

with:

```dart
    // Note: NOT calling updateStreak() here.
    // Streak is login-based — updated once per day on app open via _updateStreakIfNeeded.
```

- [ ] **Step 2: Remove redundant Container in `StreakStatusDialog`**

In `lib/presentation/widgets/common/streak_status_dialog.dart`, replace lines 198-206:

```dart
                child: Container(
                   child: Text(
                    'Close',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
```

with:

```dart
                child: Text(
                  'Close',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
```

- [ ] **Step 3: Run analysis**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/user_provider.dart lib/presentation/widgets/common/streak_status_dialog.dart
git commit -m "cleanup: fix stale comment in addXP, remove redundant Container (#10 audit fix 6,7)"
```

---

### Task 6: Update spec audit statuses

**Files:**
- Modify: `docs/specs/10-streak-system.md` — update Status column from TODO to Fixed

- [ ] **Step 1: Update audit findings table**

In `docs/specs/10-streak-system.md`, update the Status column for all fixed findings:

| # | Status change |
|---|---------------|
| 1 | TODO → Fixed |
| 2 | TODO → Fixed |
| 3 | TODO → Fixed |
| 4 | TODO → Fixed |
| 5 | TODO → Fixed |
| 6 | TODO → Fixed |
| 9 | TODO → Fixed |

Findings #7 and #8 remain as-is (configuration decisions, not bugs).

- [ ] **Step 2: Commit**

```bash
git add docs/specs/10-streak-system.md
git commit -m "docs: update streak system spec — mark audit findings as fixed"
```
