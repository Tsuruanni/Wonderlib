# Coin Economy Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 13 audit findings from Feature #13 (Coin Economy): 4 critical security gaps, 5 medium code issues, 4 low-priority items.

**Architecture:** Single SQL migration for all DB fixes (auth guards, column revoke, constraint, index). Dart-side: extract AvatarController, fix streak freeze UX, remove dead code, fix loading text.

**Tech Stack:** PostgreSQL (Supabase), Dart/Flutter (Riverpod, clean architecture)

---

### Task 1: Security Migration — Auth Guards + Column Revoke + Constraint + Index

**Files:**
- Create: `supabase/migrations/20260328100001_coin_security_hardening.sql`

This single migration fixes findings #1, #2, #3, #4, #13, #14.

- [ ] **Step 1: Create migration file**

```sql
-- Coin Economy security hardening (Findings #1-4, #13, #14)
-- Adds auth.uid() checks to 4 RPCs, revokes direct UPDATE on monetary columns,
-- adds streak_freeze_count non-negative constraint, drops redundant index.

-- =============================================
-- 1. AUTH GUARD: award_coins_transaction (#2)
-- =============================================
CREATE OR REPLACE FUNCTION award_coins_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_coins INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_coins INTEGER;
    v_new_coins INTEGER;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Lock first
    SELECT coins INTO v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Idempotency check after lock
    IF p_source_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM coin_logs
        WHERE user_id = p_user_id AND source = p_source AND source_id = p_source_id
    ) THEN
        RETURN QUERY SELECT v_current_coins;
        RETURN;
    END IF;

    v_new_coins := v_current_coins + p_amount;

    IF v_new_coins < 0 THEN
        RAISE EXCEPTION 'Insufficient coins. Current: %, Requested: %', v_current_coins, p_amount;
    END IF;

    UPDATE profiles
    SET coins = v_new_coins, updated_at = NOW()
    WHERE id = p_user_id;

    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, p_amount, v_new_coins, p_source, p_source_id, p_description);

    RETURN QUERY SELECT v_new_coins;
END;
$$;

-- =============================================
-- 2. AUTH GUARD: spend_coins_transaction (#2)
-- =============================================
CREATE OR REPLACE FUNCTION spend_coins_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_coins INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Negate amount to spend
    RETURN QUERY SELECT * FROM award_coins_transaction(
        p_user_id, -p_amount, p_source, p_source_id, p_description
    );
END;
$$;

-- =============================================
-- 3. AUTH GUARD: buy_card_pack (#3)
-- =============================================
CREATE OR REPLACE FUNCTION buy_card_pack(
    p_user_id UUID,
    p_pack_cost INTEGER DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_coins INTEGER;
    v_new_coins INTEGER;
    v_new_packs INTEGER;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Lock user row and check balance
    SELECT coins, unopened_packs INTO v_current_coins, v_new_packs
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    IF v_current_coins < p_pack_cost THEN
        RAISE EXCEPTION 'Insufficient coins. Have: %, Need: %', v_current_coins, p_pack_cost;
    END IF;

    -- Deduct coins, increment packs
    v_new_coins := v_current_coins - p_pack_cost;
    v_new_packs := v_new_packs + 1;

    UPDATE profiles
    SET coins = v_new_coins,
        unopened_packs = v_new_packs,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log coin transaction
    INSERT INTO coin_logs (user_id, amount, balance_after, source, description)
    VALUES (p_user_id, -p_pack_cost, v_new_coins, 'pack_purchase', 'Card pack purchased (stored)');

    RETURN jsonb_build_object(
        'coins_spent', p_pack_cost,
        'coins_remaining', v_new_coins,
        'unopened_packs', v_new_packs
    );
END;
$$;

-- =============================================
-- 4. AUTH GUARD: open_card_pack (#4)
-- =============================================
CREATE OR REPLACE FUNCTION open_card_pack(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_packs INTEGER;
    v_pity_counter INTEGER;
    v_total_packs INTEGER;
    v_card_ids UUID[] := ARRAY[]::UUID[];
    v_result_cards JSONB := '[]'::JSONB;
    v_selected_card RECORD;
    v_slot INTEGER;
    v_roll DOUBLE PRECISION;
    v_target_rarity VARCHAR(20);
    v_is_new BOOLEAN;
    v_current_qty INTEGER;
    v_best_rarity VARCHAR(20) := 'common';
    v_pity_triggered BOOLEAN := FALSE;
    v_rarity_order INTEGER;
    v_best_order INTEGER := 0;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- ===== 1. CHECK & DECREMENT PACK INVENTORY =====
    SELECT unopened_packs INTO v_current_packs
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    IF v_current_packs < 1 THEN
        RAISE EXCEPTION 'No unopened packs available';
    END IF;

    -- Decrement pack count
    UPDATE profiles
    SET unopened_packs = unopened_packs - 1,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- ===== 2. GET/CREATE PITY COUNTER =====
    SELECT packs_since_legendary, total_packs_opened
    INTO v_pity_counter, v_total_packs
    FROM user_card_stats
    WHERE user_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO user_card_stats (user_id, packs_since_legendary, total_packs_opened, total_unique_cards)
        VALUES (p_user_id, 0, 0, 0);
        v_pity_counter := 0;
        v_total_packs := 0;
    END IF;

    -- ===== 3. ROLL 3 CARDS =====
    FOR v_slot IN 1..3 LOOP
        v_roll := random();

        IF v_slot <= 2 THEN
            IF v_roll < 0.03 THEN
                v_target_rarity := 'legendary';
            ELSIF v_roll < 0.15 THEN
                v_target_rarity := 'epic';
            ELSIF v_roll < 0.40 THEN
                v_target_rarity := 'rare';
            ELSE
                v_target_rarity := 'common';
            END IF;
        ELSE
            IF v_pity_counter >= 14 THEN
                v_target_rarity := 'legendary';
                v_pity_triggered := TRUE;
            ELSIF v_roll < 0.10 THEN
                v_target_rarity := 'legendary';
            ELSIF v_roll < 0.40 THEN
                v_target_rarity := 'epic';
            ELSE
                v_target_rarity := 'rare';
            END IF;
        END IF;

        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = v_target_rarity
        AND mc.is_active = true
        AND mc.id != ALL(v_card_ids)
        ORDER BY random()
        LIMIT 1;

        IF NOT FOUND THEN
            SELECT mc.* INTO v_selected_card
            FROM myth_cards mc
            WHERE mc.is_active = true
            AND mc.id != ALL(v_card_ids)
            ORDER BY random()
            LIMIT 1;
        END IF;

        v_card_ids := array_append(v_card_ids, v_selected_card.id);

        -- ===== 4. UPSERT USER_CARDS =====
        SELECT quantity INTO v_current_qty
        FROM user_cards
        WHERE user_id = p_user_id AND card_id = v_selected_card.id;

        IF FOUND THEN
            v_is_new := FALSE;
            v_current_qty := v_current_qty + 1;
            UPDATE user_cards
            SET quantity = v_current_qty, updated_at = NOW()
            WHERE user_id = p_user_id AND card_id = v_selected_card.id;
        ELSE
            v_is_new := TRUE;
            v_current_qty := 1;
            INSERT INTO user_cards (user_id, card_id, quantity)
            VALUES (p_user_id, v_selected_card.id, 1);
        END IF;

        v_rarity_order := CASE v_selected_card.rarity
            WHEN 'common' THEN 1
            WHEN 'rare' THEN 2
            WHEN 'epic' THEN 3
            WHEN 'legendary' THEN 4
        END;
        IF v_rarity_order > v_best_order THEN
            v_best_order := v_rarity_order;
            v_best_rarity := v_selected_card.rarity;
        END IF;

        v_result_cards := v_result_cards || jsonb_build_object(
            'id', v_selected_card.id,
            'card_no', v_selected_card.card_no,
            'name', v_selected_card.name,
            'category', v_selected_card.category,
            'category_icon', v_selected_card.category_icon,
            'rarity', v_selected_card.rarity,
            'power', v_selected_card.power,
            'special_skill', v_selected_card.special_skill,
            'description', v_selected_card.description,
            'is_new', v_is_new,
            'quantity', v_current_qty
        );
    END LOOP;

    -- ===== 5. UPDATE PITY COUNTER =====
    IF v_best_rarity = 'legendary' THEN
        v_pity_counter := 0;
    ELSE
        v_pity_counter := v_pity_counter + 1;
    END IF;

    -- ===== 6. UPDATE STATS =====
    UPDATE user_card_stats
    SET packs_since_legendary = v_pity_counter,
        total_packs_opened = v_total_packs + 1,
        total_unique_cards = (
            SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id
        ),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- ===== 7. LOG PACK OPENING =====
    INSERT INTO pack_purchases (user_id, cost, card_ids, pity_counter_at_purchase)
    VALUES (p_user_id, 0, v_card_ids, v_pity_counter);

    -- ===== 8. RETURN RESULT =====
    RETURN jsonb_build_object(
        'cards', v_result_cards,
        'pack_glow_rarity', v_best_rarity,
        'packs_remaining', (SELECT unopened_packs FROM profiles WHERE id = p_user_id),
        'pity_triggered', v_pity_triggered
    );
END;
$$;

-- =============================================
-- 5. COLUMN-LEVEL REVOKE on profiles (#1)
-- Prevents direct UPDATE on monetary columns from authenticated role.
-- SECURITY DEFINER functions execute as owner and bypass this.
-- =============================================
REVOKE UPDATE(coins, unopened_packs, streak_freeze_count) ON profiles FROM authenticated;

-- =============================================
-- 6. streak_freeze_count non-negative constraint (#13)
-- =============================================
ALTER TABLE profiles
    ADD CONSTRAINT chk_streak_freeze_non_negative CHECK (streak_freeze_count >= 0);

-- =============================================
-- 7. Drop redundant index (#14)
-- idx_coin_logs_user_id is superseded by idx_coin_logs_user_created
-- =============================================
DROP INDEX IF EXISTS idx_coin_logs_user_id;
```

- [ ] **Step 2: Dry-run migration**

Run: `supabase db push --dry-run`
Expected: Migration listed as pending, no errors

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260328100001_coin_security_hardening.sql
git commit -m "fix: add auth guards to 4 coin RPCs, revoke direct coin UPDATE, add constraints

Fixes audit findings #1-4 (critical security), #13 (streak_freeze_count
constraint), #14 (redundant index). All spending/earning RPCs now verify
auth.uid() matches p_user_id."
```

---

### Task 2: Avatar Screen — Extract AvatarController (Findings #5, #6)

**Files:**
- Modify: `lib/presentation/providers/avatar_provider.dart` — add AvatarController
- Modify: `lib/presentation/screens/avatar/avatar_customize_screen.dart` — use controller
- Modify: `lib/presentation/providers/usecase_providers.dart` — no changes needed (usecases already registered)

- [ ] **Step 1: Add AvatarController to avatar_provider.dart**

Add at the end of `lib/presentation/providers/avatar_provider.dart`:

```dart
import '../../domain/entities/user.dart';
import '../../domain/usecases/avatar/buy_avatar_item_usecase.dart';
import '../../domain/usecases/avatar/equip_avatar_item_usecase.dart';
import '../../domain/usecases/avatar/set_avatar_base_usecase.dart';
import '../../domain/usecases/avatar/unequip_avatar_item_usecase.dart';
```

And at the bottom of the file:

```dart
/// Controller for avatar mutations (setBase, equip, unequip, buy).
/// Mirrors PackOpeningController pattern — keeps business logic out of screens.
class AvatarController extends StateNotifier<AsyncValue<void>> {
  AvatarController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  bool get isMutating => state is AsyncLoading;

  Future<String?> setBase(String baseId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(setAvatarBaseUseCaseProvider);
    final result = await useCase(SetAvatarBaseParams(baseId: baseId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Failed to set base: ${failure.message}';
      },
      (_) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> equipItem(String itemId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(equipAvatarItemUseCaseProvider);
    final result = await useCase(EquipAvatarItemParams(itemId: itemId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Failed to equip: ${failure.message}';
      },
      (_) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> unequipItem(String itemId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(unequipAvatarItemUseCaseProvider);
    final result = await useCase(UnequipAvatarItemParams(itemId: itemId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Failed to unequip: ${failure.message}';
      },
      (_) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null;
      },
    );
  }

  Future<String?> buyItem(String itemId) async {
    if (isMutating) return null;
    state = const AsyncValue.loading();
    final useCase = _ref.read(buyAvatarItemUseCaseProvider);
    final result = await useCase(BuyAvatarItemParams(itemId: itemId));
    return result.fold(
      (failure) {
        state = const AsyncValue.data(null);
        return 'Purchase failed: ${failure.message}';
      },
      (buyResult) {
        _ref.invalidate(userAvatarItemsProvider);
        _ref.read(userControllerProvider.notifier).refreshProfileOnly();
        state = const AsyncValue.data(null);
        return null; // null = success
      },
    );
  }
}

final avatarControllerProvider =
    StateNotifierProvider.autoDispose<AvatarController, AsyncValue<void>>((ref) {
  return AvatarController(ref);
});
```

- [ ] **Step 2: Refactor AvatarCustomizeScreen to use AvatarController**

Replace imports — remove direct usecase imports, add avatar_provider controller import.

Remove from screen: `_isMutating` field, `_setBase`, `_equip`, `_unequip`, `_buy` methods.

Replace `_isMutating` check in `build()` with:

```dart
final avatarController = ref.watch(avatarControllerProvider);
final isMutating = avatarController is AsyncLoading;
```

Replace the 4 callback references to use the controller:

```dart
// In _BaseAnimalRow onSelect:
onSelect: (base) async {
  final error = await ref.read(avatarControllerProvider.notifier).setBase(base.id);
  if (error != null) _showSnack(error, isError: true);
},

// In _ItemGrid onEquip:
onEquip: (item) async {
  final error = await ref.read(avatarControllerProvider.notifier).equipItem(item.id);
  if (error != null) _showSnack(error, isError: true);
},

// In _ItemGrid onUnequip:
onUnequip: (item) async {
  final error = await ref.read(avatarControllerProvider.notifier).unequipItem(item.id);
  if (error != null) _showSnack(error, isError: true);
},

// In _ItemGrid onBuy (inside _showBuyConfirmation dialog):
onPressed: () {
  Navigator.of(ctx).pop();
  () async {
    final error = await ref.read(avatarControllerProvider.notifier).buyItem(item.id);
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('${item.displayName} purchased!');
    }
  }();
},
```

The `ConsumerStatefulWidget` can become a `ConsumerWidget` if the only stateful part was `_isMutating` — but `TabController` and `SingleTickerProviderStateMixin` require `StatefulWidget`. Keep `ConsumerStatefulWidget` but remove `_isMutating`.

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/screens/avatar/avatar_customize_screen.dart lib/presentation/providers/avatar_provider.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/avatar_provider.dart lib/presentation/screens/avatar/avatar_customize_screen.dart
git commit -m "refactor: extract AvatarController, fix invalidate → refreshProfileOnly

Moves avatar mutation logic from screen to AvatarController StateNotifier.
Replaces ref.invalidate(userControllerProvider) with refreshProfileOnly()
to avoid triggering unnecessary streak RPC calls. Fixes #5, #6."
```

---

### Task 3: Streak Freeze UX — Loading + Error Feedback (Finding #7)

**Files:**
- Modify: `lib/presentation/providers/user_provider.dart:301-317` — return failure message
- Modify: `lib/presentation/widgets/common/streak_status_dialog.dart` — make stateful, add loading/error
- Modify: `lib/presentation/widgets/common/top_navbar.dart:68-71` — pass ref instead of fire-and-forget

- [ ] **Step 1: Change buyStreakFreeze to return error message**

In `lib/presentation/providers/user_provider.dart`, replace the `buyStreakFreeze` method (lines 301-317):

```dart
  /// Returns null on success, error message on failure.
  Future<String?> buyStreakFreeze() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return 'Not logged in';

    final useCase = _ref.read(buyStreakFreezeUseCaseProvider);
    final result = await useCase(BuyStreakFreezeParams(userId: userId));

    return result.fold(
      (failure) => failure.message,
      (buyResult) async {
        // Re-fetch profile to update freeze count and coins
        final getUserUseCase = _ref.read(getUserByIdUseCaseProvider);
        final userResult = await getUserUseCase(GetUserByIdParams(userId: userId));
        userResult.fold((_) => null, (user) => state = AsyncValue.data(user));
        return null;
      },
    );
  }
```

Wait — `fold` with async right branch is tricky. Better approach:

```dart
  /// Returns null on success, error message on failure.
  Future<String?> buyStreakFreeze() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return 'Not logged in';

    final useCase = _ref.read(buyStreakFreezeUseCaseProvider);
    final result = await useCase(BuyStreakFreezeParams(userId: userId));

    final buyResult = result.fold<BuyFreezeResult?>((f) => null, (r) => r);
    if (buyResult == null) {
      return result.fold((f) => f.message, (_) => 'Unknown error');
    }

    // Re-fetch profile to update freeze count and coins
    final getUserUseCase = _ref.read(getUserByIdUseCaseProvider);
    final userResult = await getUserUseCase(GetUserByIdParams(userId: userId));
    userResult.fold((_) => null, (user) => state = AsyncValue.data(user));
    return null;
  }
```

- [ ] **Step 2: Make StreakStatusDialog a ConsumerStatefulWidget**

Replace `lib/presentation/widgets/common/streak_status_dialog.dart`:

Change class declaration:

```dart
class StreakStatusDialog extends ConsumerStatefulWidget {
```

Change `onBuyFreeze` type from `VoidCallback?` to remove it entirely — dialog will handle buy internally.

Add `ConsumerState` with `_isLoading` local state:

```dart
class _StreakStatusDialogState extends ConsumerState<StreakStatusDialog> {
  bool _isLoading = false;

  Future<void> _handleBuyFreeze() async {
    setState(() => _isLoading = true);
    final error = await ref.read(userControllerProvider.notifier).buyStreakFreeze();
    if (!mounted) return;
    if (error != null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }
```

Replace the freeze button `onPressed: userCoins >= streakFreezePrice ? onBuyFreeze : null` with:

```dart
onPressed: _isLoading ? null : (widget.userCoins >= widget.streakFreezePrice ? _handleBuyFreeze : null),
```

Add loading indicator to button when `_isLoading`:

```dart
icon: _isLoading
    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
    : const Icon(Icons.ac_unit, size: 18),
```

- [ ] **Step 3: Update TopNavbar to remove fire-and-forget**

In `lib/presentation/widgets/common/top_navbar.dart`, change the `onBuyFreeze` callback (lines 68-71) — remove it entirely since the dialog now handles buy internally:

```dart
builder: (context) => StreakStatusDialog(
  currentStreak: user.currentStreak,
  longestStreak: user.longestStreak,
  calendarDays: calendarDays,
  streakFreezeCount: user.streakFreezeCount,
  streakFreezeMax: settings.streakFreezeMax,
  streakFreezePrice: settings.streakFreezePrice,
  userCoins: user.coins,
),
```

Remove the `onBuyFreeze` parameter entirely from the constructor call. The dialog manages it internally now.

- [ ] **Step 4: Verify**

Run: `dart analyze lib/presentation/widgets/common/streak_status_dialog.dart lib/presentation/widgets/common/top_navbar.dart lib/presentation/providers/user_provider.dart`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/user_provider.dart lib/presentation/widgets/common/streak_status_dialog.dart lib/presentation/widgets/common/top_navbar.dart
git commit -m "fix: add loading state and error feedback to streak freeze purchase

StreakStatusDialog is now a ConsumerStatefulWidget that handles buy
internally with loading indicator and error snackbar. Fixes #7."
```

---

### Task 4: Dead Code Cleanup (Findings #8, #9, #10)

**Files:**
- Delete: `lib/domain/usecases/card/get_user_coins_usecase.dart`
- Delete: `lib/domain/usecases/card/get_cards_by_category_usecase.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart:684-702` — remove 2 dead providers
- Modify: `lib/presentation/providers/card_provider.dart:80-160` — remove 3 dead providers
- Modify: `lib/domain/repositories/card_repository.dart` — remove 2 dead methods
- Modify: `lib/data/repositories/supabase/supabase_card_repository.dart` — remove 2 dead implementations

- [ ] **Step 1: Delete dead usecase files**

```bash
rm lib/domain/usecases/card/get_user_coins_usecase.dart
rm lib/domain/usecases/card/get_cards_by_category_usecase.dart
```

- [ ] **Step 2: Remove dead providers from usecase_providers.dart**

In `lib/presentation/providers/usecase_providers.dart`, remove lines 684-686 (`getCardsByCategoryUseCaseProvider`) and lines 700-702 (`getUserCoinsUseCaseProvider`).

Also remove the corresponding imports at the top of the file:
```dart
import '../../domain/usecases/card/get_cards_by_category_usecase.dart';
import '../../domain/usecases/card/get_user_coins_usecase.dart';
```

- [ ] **Step 3: Remove dead providers from card_provider.dart**

In `lib/presentation/providers/card_provider.dart`, remove:

1. `collectionByCategoryProvider` (lines 80-88) — superseded by `sortedCollectionByCategoryProvider`
2. `selectedCategoryProvider` (line 152) — the card variant, not used by any screen
3. `filteredCatalogProvider` (lines 155-160) — depends on the dead `selectedCategoryProvider`

- [ ] **Step 4: Remove dead methods from CardRepository interface**

In `lib/domain/repositories/card_repository.dart`, remove:

```dart
  /// Get cards filtered by mythology category
  Future<Either<Failure, List<MythCard>>> getCardsByCategory(CardCategory category);

  /// Get user's current coin balance
  Future<Either<Failure, int>> getUserCoins(String userId);
```

- [ ] **Step 5: Remove dead implementations from SupabaseCardRepository**

In `lib/data/repositories/supabase/supabase_card_repository.dart`, remove:

1. `getCardsByCategory()` method (lines 42-61)
2. `getUserCoins()` method (lines 151-165)

- [ ] **Step 6: Verify**

Run: `dart analyze lib/`
Expected: No issues (or pre-existing issues unrelated to this change)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: remove dead coin/card code — GetUserCoinsUseCase, GetCardsByCategoryUseCase, 3 unused providers

Removes unused usecases, providers, and repository methods identified in
coin economy audit. Fixes #8, #9, #10."
```

---

### Task 5: Fix Pack Opening Loading Text (Finding #12)

**Files:**
- Modify: `lib/presentation/screens/cards/pack_opening_screen.dart:187-193, 417-441`

- [ ] **Step 1: Split buying and opening phases in the switch**

In `pack_opening_screen.dart`, replace the combined case (lines 191-193):

```dart
      case PackOpeningPhase.buying:
        return _buildPurchasingPhase('Buying pack...');

      case PackOpeningPhase.opening:
        return _buildPurchasingPhase('Opening pack...');
```

- [ ] **Step 2: Add text parameter to _buildPurchasingPhase**

Replace `_buildPurchasingPhase()` (lines 417-441):

```dart
  Widget _buildPurchasingPhase(String message) {
    return Column(
      key: const ValueKey('purchasing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            color: AppColors.cardEpic,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 3: Verify**

Run: `dart analyze lib/presentation/screens/cards/pack_opening_screen.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/cards/pack_opening_screen.dart
git commit -m "fix: show 'Buying pack...' during buy phase, not 'Opening pack...'

Splits PackOpeningPhase.buying and .opening into separate switch cases
with correct loading text. Fixes #12."
```

---

### Task 6: Update Feature Spec + Final Verify

**Files:**
- Modify: `docs/specs/13-coin-economy.md` — mark fixed findings

- [ ] **Step 1: Update spec audit table**

In `docs/specs/13-coin-economy.md`, update the Status column for all fixed findings:

| # | Status change |
|---|---------------|
| 1 | TODO → Fixed |
| 2 | TODO → Fixed |
| 3 | TODO → Fixed |
| 4 | TODO → Fixed |
| 5 | TODO → Fixed |
| 6 | TODO → Fixed |
| 7 | TODO → Fixed |
| 8 | TODO → Fixed |
| 9 | TODO → Fixed |
| 10 | TODO → Fixed |
| 12 | TODO → Fixed |
| 13 | TODO → Fixed |
| 14 | TODO → Fixed |

Update checklist result section to reflect fixes.

- [ ] **Step 2: Run full analyze**

Run: `dart analyze lib/`
Expected: No new issues

- [ ] **Step 3: Commit**

```bash
git add docs/specs/13-coin-economy.md
git commit -m "docs: update coin economy spec — mark 13 audit findings as fixed"
```
