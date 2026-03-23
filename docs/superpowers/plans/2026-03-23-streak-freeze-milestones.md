# Streak Freeze & Milestones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add streak freeze purchase/consumption, streak milestone bonus XP, and streak event notifications (milestone, freeze-saved, streak-broken).

**Architecture:** Modify `update_user_streak` RPC to handle freeze consumption and milestone awards. Add `buy_streak_freeze` RPC. New `StreakResult` entity flows from RPC → repository → provider → event dialog. Streak dialog gets freeze section with buy button.

**Tech Stack:** Supabase PostgreSQL (RPC), Flutter/Riverpod, owlio_shared constants.

**Spec:** `docs/superpowers/specs/2026-03-23-streak-freeze-milestones-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `supabase/migrations/20260323000005_streak_freeze_and_milestones.sql` | DB column, settings, modified RPC, new RPC |
| Modify | `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `buyStreakFreeze` constant |
| Create | `lib/domain/entities/streak_result.dart` | `StreakResult` entity |
| Modify | `lib/domain/entities/user.dart` | Add `streakFreezeCount` field |
| Modify | `lib/domain/entities/system_settings.dart` | Add `streakFreezePrice`, `streakFreezeMax` |
| Modify | `lib/data/models/user/user_model.dart` | Map `streak_freeze_count` |
| Modify | `lib/data/models/settings/system_settings_model.dart` | Parse new settings |
| Modify | `lib/domain/repositories/user_repository.dart` | Change `updateStreak` return type, add `buyStreakFreeze` |
| Modify | `lib/domain/usecases/user/update_streak_usecase.dart` | Return type → `StreakResult` |
| Create | `lib/domain/usecases/user/buy_streak_freeze_usecase.dart` | Buy freeze use case |
| Modify | `lib/data/repositories/supabase/supabase_user_repository.dart` | Parse RPC result, implement `buyStreakFreeze` |
| Modify | `lib/presentation/providers/usecase_providers.dart` | Register `BuyStreakFreezeUseCase` |
| Modify | `lib/presentation/providers/user_provider.dart` | `streakEventProvider`, updated `updateStreak()`, new `buyStreakFreeze()` |
| Modify | `lib/presentation/widgets/common/streak_status_dialog.dart` | Freeze section + buy button |
| Create | `lib/presentation/widgets/common/streak_event_dialog.dart` | Milestone / freeze-saved / streak-broken dialogs |
| Modify | `lib/presentation/widgets/common/level_up_celebration.dart` | Add streak event listener |
| Modify | `lib/core/services/edge_function_service.dart` | Delete old `StreakResult` + `checkStreak()` |
| Modify | `lib/core/constants/app_constants.dart` | Delete `streakResetHours` |

---

## Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/20260323000005_streak_freeze_and_milestones.sql`

- [ ] **Step 1: Write the migration**

```sql
-- =============================================
-- Streak Freeze & Milestones
-- =============================================

-- 1. Add streak_freeze_count to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS streak_freeze_count INTEGER DEFAULT 0;

-- 2. Add settings for streak freeze
INSERT INTO system_settings (key, value, category, description) VALUES
  ('streak_freeze_price', '50', 'progression', 'Coin cost to buy one streak freeze'),
  ('streak_freeze_max', '2', 'progression', 'Maximum streak freezes a user can hold')
ON CONFLICT (key) DO NOTHING;

-- 3. Modified update_user_streak with freeze + milestones
CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID)
RETURNS TABLE(
    new_streak INTEGER,
    longest_streak INTEGER,
    streak_broken BOOLEAN,
    streak_extended BOOLEAN,
    freeze_used BOOLEAN,
    freezes_consumed INTEGER,
    freezes_remaining INTEGER,
    milestone_bonus_xp INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_activity DATE;
    v_current_streak INTEGER;
    v_longest_streak INTEGER;
    v_freeze_count INTEGER;
    v_today DATE := CURRENT_DATE;
    v_new_streak INTEGER;
    v_streak_broken BOOLEAN := FALSE;
    v_streak_extended BOOLEAN := FALSE;
    v_freeze_used BOOLEAN := FALSE;
    v_freezes_consumed INTEGER := 0;
    v_days_missed INTEGER;
    v_milestone_xp INTEGER := 0;
BEGIN
    -- Get current streak info with row lock
    SELECT p.last_activity_date, p.current_streak, p.longest_streak, p.streak_freeze_count
    INTO v_last_activity, v_current_streak, v_longest_streak, v_freeze_count
    FROM profiles p
    WHERE p.id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Calculate new streak
    IF v_last_activity IS NULL THEN
        -- First activity ever
        v_new_streak := 1;
        v_streak_extended := TRUE;
    ELSIF v_last_activity = v_today THEN
        -- Same day, no change
        v_new_streak := v_current_streak;
    ELSIF v_last_activity = v_today - 1 THEN
        -- Consecutive day
        v_new_streak := v_current_streak + 1;
        v_streak_extended := TRUE;
    ELSE
        -- Gap >= 2 days — check freezes
        v_days_missed := (v_today - v_last_activity) - 1;

        IF v_days_missed <= v_freeze_count THEN
            -- All missed days covered by freezes
            v_freeze_count := v_freeze_count - v_days_missed;
            v_new_streak := v_current_streak + 1;
            v_streak_extended := TRUE;
            v_freeze_used := TRUE;
            v_freezes_consumed := v_days_missed;
        ELSIF v_freeze_count > 0 THEN
            -- Partial coverage: not enough freezes
            v_freezes_consumed := v_freeze_count;
            v_freeze_count := 0;
            v_new_streak := 1;
            v_streak_broken := TRUE;
            v_freeze_used := TRUE;
        ELSE
            -- No freezes
            v_new_streak := 1;
            v_streak_broken := TRUE;
        END IF;
    END IF;

    -- Update longest streak
    IF v_new_streak > v_longest_streak THEN
        v_longest_streak := v_new_streak;
    END IF;

    -- Milestone bonus (only when streak extended)
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
                NULL, 'Streak milestone: ' || v_new_streak || ' days'
            );
        END IF;
    END IF;

    -- Update profile
    UPDATE profiles
    SET current_streak = v_new_streak,
        longest_streak = v_longest_streak,
        last_activity_date = v_today,
        streak_freeze_count = v_freeze_count,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT v_new_streak, v_longest_streak, v_streak_broken, v_streak_extended,
                        v_freeze_used, v_freezes_consumed, v_freeze_count, v_milestone_xp;
END;
$$;

COMMENT ON FUNCTION update_user_streak IS 'Update user streak with freeze support and milestone bonuses';

-- 4. New RPC: buy_streak_freeze
CREATE OR REPLACE FUNCTION buy_streak_freeze(p_user_id UUID)
RETURNS TABLE(success BOOLEAN, freeze_count INTEGER, coins_remaining INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_max INTEGER;
    v_price INTEGER;
    v_current_freezes INTEGER;
    v_current_coins INTEGER;
    v_new_coins INTEGER;
BEGIN
    -- Auth check
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Read settings
    SELECT (value)::INT INTO v_max FROM system_settings WHERE key = 'streak_freeze_max';
    SELECT (value)::INT INTO v_price FROM system_settings WHERE key = 'streak_freeze_price';

    -- Defaults if settings not found
    v_max := COALESCE(v_max, 2);
    v_price := COALESCE(v_price, 50);

    -- Lock and read profile
    SELECT p.streak_freeze_count, p.coins
    INTO v_current_freezes, v_current_coins
    FROM profiles p
    WHERE p.id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- Validate
    IF v_current_freezes >= v_max THEN
        RAISE EXCEPTION 'max_freezes_reached';
    END IF;

    IF v_current_coins < v_price THEN
        RAISE EXCEPTION 'insufficient_coins';
    END IF;

    -- Spend coins using existing transaction function
    SELECT sc.new_coins INTO v_new_coins
    FROM spend_coins_transaction(p_user_id, v_price, 'streak_freeze', NULL, 'Purchased streak freeze') sc;

    -- Increment freeze count
    UPDATE profiles
    SET streak_freeze_count = streak_freeze_count + 1,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN QUERY SELECT TRUE, v_current_freezes + 1, v_new_coins;
END;
$$;

COMMENT ON FUNCTION buy_streak_freeze IS 'Purchase a streak freeze with coins';
```

- [ ] **Step 2: Dry-run**

Run: `supabase db push --dry-run`
Expected: Shows migration as pending, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260323000005_streak_freeze_and_milestones.sql
git commit -m "feat(db): add streak freeze column, settings, modified RPC with milestones, buy_streak_freeze RPC"
```

---

## Task 2: Shared Package + Dead Code Cleanup

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart:29`
- Modify: `lib/core/services/edge_function_service.dart:47-66,169-200`
- Modify: `lib/core/constants/app_constants.dart:34`

- [ ] **Step 1: Add RPC constant**

In `rpc_functions.dart`, after `getQuestCompletionStats` (line ~30), add:

```dart
  static const buyStreakFreeze = 'buy_streak_freeze';
```

- [ ] **Step 2: Delete old StreakResult from edge_function_service.dart**

Delete the `StreakResult` class (lines 169-200) and the `checkStreak()` method (lines 47-66) from `lib/core/services/edge_function_service.dart`. Keep the rest of the file intact.

- [ ] **Step 3: Delete streakResetHours from app_constants.dart**

Remove line 34: `static const streakResetHours = 48;`

- [ ] **Step 4: Verify**

Run: `dart analyze lib/core/ packages/owlio_shared/`
Expected: No new issues. If any file was importing the old `StreakResult`, it will fail — search and fix.

- [ ] **Step 5: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/rpc_functions.dart lib/core/services/edge_function_service.dart lib/core/constants/app_constants.dart
git commit -m "feat(shared): add buyStreakFreeze RPC constant, clean up dead streak code"
```

---

## Task 3: Domain Layer — Entities + Repository Interface

**Files:**
- Create: `lib/domain/entities/streak_result.dart`
- Modify: `lib/domain/entities/user.dart`
- Modify: `lib/domain/entities/system_settings.dart`
- Modify: `lib/domain/repositories/user_repository.dart`

- [ ] **Step 1: Create StreakResult entity**

```dart
// lib/domain/entities/streak_result.dart
import 'package:equatable/equatable.dart';

class StreakResult extends Equatable {
  const StreakResult({
    required this.newStreak,
    required this.longestStreak,
    this.streakBroken = false,
    this.streakExtended = false,
    this.freezeUsed = false,
    this.freezesConsumed = 0,
    this.freezesRemaining = 0,
    this.milestoneBonusXp = 0,
  });

  final int newStreak;
  final int longestStreak;
  final bool streakBroken;
  final bool streakExtended;
  final bool freezeUsed;
  final int freezesConsumed;
  final int freezesRemaining;
  final int milestoneBonusXp;

  /// True if this result has any event worth showing to the user
  bool get hasEvent => milestoneBonusXp > 0 || freezeUsed || streakBroken;

  @override
  List<Object?> get props => [
        newStreak, longestStreak, streakBroken, streakExtended,
        freezeUsed, freezesConsumed, freezesRemaining, milestoneBonusXp,
      ];
}

class BuyFreezeResult {
  const BuyFreezeResult({
    required this.freezeCount,
    required this.coinsRemaining,
  });

  final int freezeCount;
  final int coinsRemaining;
}
```

- [ ] **Step 2: Add streakFreezeCount to User entity**

In `lib/domain/entities/user.dart`:

Add field `this.streakFreezeCount = 0` to constructor (after `longestStreak`).
Add `final int streakFreezeCount;` to field declarations (after `longestStreak`).
Add `int? streakFreezeCount` to `copyWith` params and body.
Add `streakFreezeCount` to `props` list (after `longestStreak`).

- [ ] **Step 3: Add freeze settings to SystemSettings entity**

In `lib/domain/entities/system_settings.dart`:

Add to constructor (after `streakBonusIncrement`):
```dart
    this.streakFreezePrice = 50,
    this.streakFreezeMax = 2,
```

Add fields:
```dart
  final int streakFreezePrice;
  final int streakFreezeMax;
```

Add to `props` list (after `streakBonusIncrement`).

- [ ] **Step 4: Update UserRepository interface**

In `lib/domain/repositories/user_repository.dart`:

Change line 14:
```dart
  Future<Either<Failure, StreakResult>> updateStreak(String userId);
```

Add import at top:
```dart
import '../entities/streak_result.dart';
```

Add new method:
```dart
  Future<Either<Failure, BuyFreezeResult>> buyStreakFreeze(String userId);
```

- [ ] **Step 5: Verify**

Run: `dart analyze lib/domain/`
Expected: Errors in `update_streak_usecase.dart` and `supabase_user_repository.dart` (return type mismatch). These will be fixed in Tasks 4 and 5.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/streak_result.dart lib/domain/entities/user.dart lib/domain/entities/system_settings.dart lib/domain/repositories/user_repository.dart
git commit -m "feat(domain): add StreakResult entity, streakFreezeCount on User, freeze settings, updated repository interface"
```

---

## Task 4: Data Layer — Models + Repository Implementation

**Files:**
- Modify: `lib/data/models/user/user_model.dart`
- Modify: `lib/data/models/settings/system_settings_model.dart`
- Modify: `lib/data/repositories/supabase/supabase_user_repository.dart:93-119`

- [ ] **Step 1: Add streakFreezeCount to UserModel**

In `lib/data/models/user/user_model.dart`:

Add `this.streakFreezeCount = 0` to constructor.
Add `final int streakFreezeCount;` to fields.

In `fromJson`: add after `longestStreak`:
```dart
      streakFreezeCount: json['streak_freeze_count'] as int? ?? 0,
```

In `fromEntity`: add:
```dart
      streakFreezeCount: entity.streakFreezeCount,
```

In `toJson`: add:
```dart
      'streak_freeze_count': streakFreezeCount,
```

In `toEntity`: add to constructor call:
```dart
      streakFreezeCount: streakFreezeCount,
```

- [ ] **Step 2: Add freeze settings to SystemSettingsModel**

In `lib/data/models/settings/system_settings_model.dart`:

Add `required this.streakFreezePrice` and `required this.streakFreezeMax` to constructor.
Add fields: `final int streakFreezePrice;` and `final int streakFreezeMax;`.

In `fromMap`, add after `streakBonusIncrement`:
```dart
      streakFreezePrice: _toInt(m['streak_freeze_price'], 50),
      streakFreezeMax: _toInt(m['streak_freeze_max'], 2),
```

In `defaults()` factory, add:
```dart
        streakFreezePrice: 50,
        streakFreezeMax: 2,
```

In `toEntity()`, add:
```dart
        streakFreezePrice: streakFreezePrice,
        streakFreezeMax: streakFreezeMax,
```

In `fromEntity()`, add:
```dart
        streakFreezePrice: e.streakFreezePrice,
        streakFreezeMax: e.streakFreezeMax,
```

- [ ] **Step 3: Update SupabaseUserRepository.updateStreak()**

Replace the `updateStreak` method (lines 93-119) in `lib/data/repositories/supabase/supabase_user_repository.dart`:

```dart
  @override
  Future<Either<Failure, StreakResult>> updateStreak(String userId) async {
    try {
      final response = await _supabase.rpc(RpcFunctions.updateUserStreak, params: {
        'p_user_id': userId,
      });

      // Check for new badges (including streak badges)
      await _supabase.rpc(RpcFunctions.checkAndAwardBadges, params: {
        'p_user_id': userId,
      });

      // Parse RPC result (returns a list with one row)
      final List rows = response is List ? response : [response];
      if (rows.isEmpty) {
        return const Left(ServerFailure('No streak result returned'));
      }

      final row = rows.first as Map<String, dynamic>;
      return Right(StreakResult(
        newStreak: row['new_streak'] as int? ?? 0,
        longestStreak: row['longest_streak'] as int? ?? 0,
        streakBroken: row['streak_broken'] as bool? ?? false,
        streakExtended: row['streak_extended'] as bool? ?? false,
        freezeUsed: row['freeze_used'] as bool? ?? false,
        freezesConsumed: row['freezes_consumed'] as int? ?? 0,
        freezesRemaining: row['freezes_remaining'] as int? ?? 0,
        milestoneBonusXp: row['milestone_bonus_xp'] as int? ?? 0,
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

Add import at top of file:
```dart
import '../../../domain/entities/streak_result.dart';
```

- [ ] **Step 4: Add buyStreakFreeze to SupabaseUserRepository**

Add after the `updateStreak` method:

```dart
  @override
  Future<Either<Failure, BuyFreezeResult>> buyStreakFreeze(String userId) async {
    try {
      final response = await _supabase.rpc(RpcFunctions.buyStreakFreeze, params: {
        'p_user_id': userId,
      });

      final List rows = response is List ? response : [response];
      if (rows.isEmpty) {
        return const Left(ServerFailure('No result returned'));
      }

      final row = rows.first as Map<String, dynamic>;
      return Right(BuyFreezeResult(
        freezeCount: row['freeze_count'] as int? ?? 0,
        coinsRemaining: row['coins_remaining'] as int? ?? 0,
      ));
    } on PostgrestException catch (e) {
      if (e.message.contains('max_freezes_reached')) {
        return const Left(ServerFailure('Maximum streak freezes reached'));
      }
      if (e.message.contains('insufficient_coins')) {
        return const Left(ServerFailure('Not enough coins'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
```

- [ ] **Step 5: Verify**

Run: `dart analyze lib/data/`
Expected: No new issues in data layer.

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/user/user_model.dart lib/data/models/settings/system_settings_model.dart lib/data/repositories/supabase/supabase_user_repository.dart
git commit -m "feat(data): add streak freeze to UserModel, SystemSettingsModel, update repository with StreakResult parsing"
```

---

## Task 5: Use Cases + Provider Registration

**Files:**
- Modify: `lib/domain/usecases/user/update_streak_usecase.dart`
- Create: `lib/domain/usecases/user/buy_streak_freeze_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`

- [ ] **Step 1: Update UpdateStreakUseCase**

Replace `lib/domain/usecases/user/update_streak_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/streak_result.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class UpdateStreakParams {
  const UpdateStreakParams({required this.userId});
  final String userId;
}

class UpdateStreakUseCase implements UseCase<StreakResult, UpdateStreakParams> {
  const UpdateStreakUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, StreakResult>> call(UpdateStreakParams params) {
    return _repository.updateStreak(params.userId);
  }
}
```

- [ ] **Step 2: Create BuyStreakFreezeUseCase**

```dart
// lib/domain/usecases/user/buy_streak_freeze_usecase.dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/streak_result.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class BuyStreakFreezeParams {
  const BuyStreakFreezeParams({required this.userId});
  final String userId;
}

class BuyStreakFreezeUseCase implements UseCase<BuyFreezeResult, BuyStreakFreezeParams> {
  const BuyStreakFreezeUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Either<Failure, BuyFreezeResult>> call(BuyStreakFreezeParams params) {
    return _repository.buyStreakFreeze(params.userId);
  }
}
```

- [ ] **Step 3: Register in usecase_providers.dart**

Add import at top:
```dart
import '../../domain/usecases/user/buy_streak_freeze_usecase.dart';
```

Add after `updateStreakUseCaseProvider` (around line 437):
```dart
final buyStreakFreezeUseCaseProvider = Provider((ref) {
  return BuyStreakFreezeUseCase(ref.watch(userRepositoryProvider));
});
```

- [ ] **Step 4: Verify**

Run: `dart analyze lib/domain/usecases/user/ lib/presentation/providers/usecase_providers.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/user/update_streak_usecase.dart lib/domain/usecases/user/buy_streak_freeze_usecase.dart lib/presentation/providers/usecase_providers.dart
git commit -m "feat(domain): update UpdateStreakUseCase return type, add BuyStreakFreezeUseCase"
```

---

## Task 6: UserController — Streak Event Provider + Updated Logic

**Files:**
- Modify: `lib/presentation/providers/user_provider.dart`

- [ ] **Step 1: Add streakEventProvider and import**

Add import at top:
```dart
import '../../domain/entities/streak_result.dart';
import '../../domain/usecases/user/buy_streak_freeze_usecase.dart';
```

Add after `leagueTierChangeEventProvider` (around line 43):
```dart
/// Provider for streak events (milestone, freeze-saved, streak-broken)
final streakEventProvider = StateProvider<StreakResult?>((ref) => null);
```

- [ ] **Step 2: Update updateStreak() method**

Replace the `updateStreak()` method (lines 179-193):

```dart
  Future<void> updateStreak() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final useCase = _ref.read(updateStreakUseCaseProvider);
    final result = await useCase(UpdateStreakParams(userId: userId));

    result.fold(
      (failure) => null,
      (streakResult) async {
        // Silent re-fetch profile (no loading state flash)
        final userId = _ref.read(currentUserIdProvider);
        if (userId != null) {
          final getUserUseCase = _ref.read(getUserByIdUseCaseProvider);
          final userResult = await getUserUseCase(GetUserByIdParams(userId: userId));
          userResult.fold((_) => null, (user) => state = AsyncValue.data(user));
        }
        _ref.invalidate(activityHistoryProvider);

        // Fire streak event if anything notable happened
        if (streakResult.hasEvent) {
          _ref.read(streakEventProvider.notifier).state = streakResult;
        }
      },
    );
  }
```

- [ ] **Step 3: Add buyStreakFreeze() method**

Add after `updateStreak()`:

```dart
  Future<bool> buyStreakFreeze() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return false;

    final useCase = _ref.read(buyStreakFreezeUseCaseProvider);
    final result = await useCase(BuyStreakFreezeParams(userId: userId));

    return result.fold(
      (failure) => false,
      (buyResult) async {
        // Silent re-fetch profile to update freeze count and coins
        final getUserUseCase = _ref.read(getUserByIdUseCaseProvider);
        final userResult = await getUserUseCase(GetUserByIdParams(userId: userId));
        userResult.fold((_) => null, (user) => state = AsyncValue.data(user));
        return true;
      },
    );
  }
```

- [ ] **Step 4: Clear streakEventProvider on logout**

In the auth listener (around line 88), after clearing other event providers, add:
```dart
        _ref.read(streakEventProvider.notifier).state = null;
```

- [ ] **Step 5: Verify**

Run: `dart analyze lib/presentation/providers/user_provider.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/providers/user_provider.dart
git commit -m "feat(providers): add streakEventProvider, updated updateStreak with StreakResult, buyStreakFreeze"
```

---

## Task 7: Streak Status Dialog — Freeze Section + Buy Button

**Files:**
- Modify: `lib/presentation/widgets/common/streak_status_dialog.dart`

- [ ] **Step 1: Add freeze params to constructor**

Change constructor to accept freeze info:

```dart
class StreakStatusDialog extends StatelessWidget {
  const StreakStatusDialog({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDates,
    required this.streakFreezeCount,
    required this.streakFreezeMax,
    required this.streakFreezePrice,
    required this.userCoins,
    required this.onBuyFreeze,
  });

  final int currentStreak;
  final int longestStreak;
  final List<DateTime> activeDates;
  final int streakFreezeCount;
  final int streakFreezeMax;
  final int streakFreezePrice;
  final int userCoins;
  final VoidCallback? onBuyFreeze;
```

- [ ] **Step 2: Add freeze section to build method**

After the "Longest Streak" container (line 126) and before the Close button (line 131), add:

```dart
            // Streak Freeze Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ac_unit, color: Colors.blue.shade400, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Streak Freezes: $streakFreezeCount/$streakFreezeMax',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (streakFreezeCount < streakFreezeMax)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: userCoins >= streakFreezePrice ? onBuyFreeze : null,
                  icon: const Icon(Icons.ac_unit, size: 18),
                  label: Text('Buy Freeze ($streakFreezePrice coins)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    side: BorderSide(color: Colors.blue.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (streakFreezeCount >= streakFreezeMax)
              Text(
                'Max freezes reached',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 16),
```

- [ ] **Step 3: Update all callers of StreakStatusDialog**

Search for all callers of `StreakStatusDialog(` and update them to pass the new params. The caller is in `lib/presentation/widgets/common/top_navbar.dart`. The dialog needs access to user state and system settings.

Find the `showDialog` call in `top_navbar.dart` that creates `StreakStatusDialog` and update it to pass:
```dart
streakFreezeCount: user.streakFreezeCount,
streakFreezeMax: systemSettings.streakFreezeMax,  // from systemSettingsProvider
streakFreezePrice: systemSettings.streakFreezePrice,
userCoins: user.coins,
onBuyFreeze: () async {
  final success = await ref.read(userControllerProvider.notifier).buyStreakFreeze();
  if (success && context.mounted) {
    Navigator.of(context).pop();  // Close dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Streak freeze purchased!'), duration: Duration(seconds: 2)),
    );
  }
},
```

Note: The caller will need to watch `systemSettingsProvider` to get freeze price/max. Check how `systemSettingsProvider` is set up and import it.

- [ ] **Step 4: Verify**

Run: `dart analyze lib/presentation/widgets/common/streak_status_dialog.dart lib/presentation/widgets/common/top_navbar.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/common/streak_status_dialog.dart lib/presentation/widgets/common/top_navbar.dart
git commit -m "feat(ui): add streak freeze section and buy button to streak dialog"
```

---

## Task 8: Streak Event Dialogs + Listener

**Files:**
- Create: `lib/presentation/widgets/common/streak_event_dialog.dart`
- Modify: `lib/presentation/widgets/common/level_up_celebration.dart`

- [ ] **Step 1: Create streak event dialog**

```dart
// lib/presentation/widgets/common/streak_event_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/streak_result.dart';

class StreakEventDialog extends StatelessWidget {
  const StreakEventDialog({super.key, required this.result});

  final StreakResult result;

  @override
  Widget build(BuildContext context) {
    // Priority: milestone > freeze-saved > streak-broken
    if (result.milestoneBonusXp > 0) {
      return _buildMilestoneDialog(context);
    } else if (result.freezeUsed && !result.streakBroken) {
      return _buildFreezeSavedDialog(context);
    } else if (result.streakBroken) {
      return _buildStreakBrokenDialog(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMilestoneDialog(BuildContext context) {
    return _buildDialog(
      context,
      icon: Icons.local_fire_department_rounded,
      iconColor: AppColors.streakOrange,
      title: '${result.newStreak}-Day Streak!',
      subtitle: '+${result.milestoneBonusXp} XP earned!',
      subtitleColor: AppColors.streakOrange,
    );
  }

  Widget _buildFreezeSavedDialog(BuildContext context) {
    return _buildDialog(
      context,
      icon: Icons.ac_unit,
      iconColor: Colors.blue.shade400,
      title: 'Streak Freeze Saved You!',
      subtitle: 'Your ${result.newStreak}-day streak is safe.\n${result.freezesRemaining} freeze${result.freezesRemaining == 1 ? '' : 's'} left.',
      subtitleColor: Colors.blue.shade600,
    );
  }

  Widget _buildStreakBrokenDialog(BuildContext context) {
    final message = result.freezesConsumed > 0
        ? 'Your ${result.freezesConsumed} freeze${result.freezesConsumed == 1 ? '' : 's'} covered ${result.freezesConsumed} day${result.freezesConsumed == 1 ? '' : 's'}, but you were away too long.'
        : 'Start building again!';

    return _buildDialog(
      context,
      icon: Icons.local_fire_department_rounded,
      iconColor: Colors.grey.shade400,
      title: 'Streak Broken',
      subtitle: message,
      subtitleColor: Colors.grey.shade600,
    );
  }

  Widget _buildDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 72),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add streak event listener to LevelUpCelebrationListener**

In `lib/presentation/widgets/common/level_up_celebration.dart`, add imports:

```dart
import '../../../domain/entities/streak_result.dart';
import 'streak_event_dialog.dart';
```

In the `build` method, after the `ref.listen<LeagueTierChangeEvent?>` block (around line 30), add:

```dart
    ref.listen<StreakResult?>(streakEventProvider, (previous, next) {
      if (next != null && next.hasEvent) {
        _showStreakEvent(ref, next);
      }
    });
```

Add the handler method in `LevelUpCelebrationListener`:

```dart
  void _showStreakEvent(WidgetRef ref, StreakResult result) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => StreakEventDialog(result: result),
    ).then((_) {
      ref.read(streakEventProvider.notifier).state = null;
    });
  }
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/widgets/common/`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/common/streak_event_dialog.dart lib/presentation/widgets/common/level_up_celebration.dart
git commit -m "feat(ui): add streak event dialogs (milestone, freeze-saved, streak-broken)"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Full analyze**

Run: `dart analyze lib/`
Expected: No new issues.

- [ ] **Step 2: Manual test checklist**

Run: `flutter run -d chrome`

Verify:
1. Streak dialog (fire icon) shows freeze section: "Streak Freezes: 0/2"
2. Buy Freeze button works (deducts 50 coins, count goes to 1/2)
3. Buy second freeze → 2/2, button shows "Max freezes reached"
4. Buy button disabled when insufficient coins
5. Milestone notification at 7-day streak (need test user with 6-day streak)
6. Streak broken notification when returning after gap (need to simulate)
7. Freeze consumed notification when freeze covers gap
