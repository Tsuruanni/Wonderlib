# Coin Economy Audit Fixes

## Context

Feature #13 (Coin Economy) audit found 18 issues. This design covers fixing 13 of them across 3 tiers. 5 cosmetic/design-choice findings are deferred.

## Tier 1: Security Migration

Single migration `supabase/migrations/20260328100001_coin_security_hardening.sql`:

### Auth guards on 4 RPCs

Add `IF p_user_id != auth.uid() THEN RAISE EXCEPTION 'Not authorized: user mismatch'; END IF;` to:
- `buy_card_pack` — `CREATE OR REPLACE`, add auth check before row lock
- `open_card_pack` — `CREATE OR REPLACE`, add auth check before row lock
- `award_coins_transaction` — `CREATE OR REPLACE`, add auth check before row lock
- `spend_coins_transaction` — `CREATE OR REPLACE`, add auth check before row lock

Pattern reference: `20260328000004_add_auth_check_to_award_xp.sql`

**Exception for `spend_coins_transaction`**: This function is called internally by `buy_streak_freeze` and `buy_avatar_item` (which pass the authenticated user's ID). The auth check will still pass because the caller already verified `auth.uid()`. However, `spend_coins_transaction` is also called from `award_coins_transaction` (indirectly via negation pattern). Need to verify the call chain.

**Actually — `spend_coins_transaction` is a thin wrapper that calls `award_coins_transaction(-amount)`.** And `award_coins_transaction` is called by other SECURITY DEFINER functions. If we add `auth.uid() != p_user_id` to `award_coins_transaction`, it will fail when called from `buy_streak_freeze` → `spend_coins_transaction` → `award_coins_transaction` because inside a SECURITY DEFINER function, `auth.uid()` still returns the original caller's JWT.

Wait — in PostgreSQL/Supabase, `auth.uid()` reads from the JWT which persists through SECURITY DEFINER call chains. So if a user calls `buy_streak_freeze(their_own_id)`, then inside `spend_coins_transaction(their_own_id)` → `award_coins_transaction(their_own_id, -amount)`, `auth.uid()` still equals `their_own_id`. The check passes.

The auth check is safe to add to all 4 functions.

### Column-level grant restriction on profiles

```sql
REVOKE UPDATE(coins, unopened_packs, streak_freeze_count) ON profiles FROM authenticated;
```

SECURITY DEFINER functions bypass this because they execute as the function owner (postgres), not as the authenticated role.

### Additional fixes in same migration

- `ALTER TABLE profiles ADD CONSTRAINT chk_streak_freeze_non_negative CHECK (streak_freeze_count >= 0);` (Finding #13)
- `DROP INDEX IF EXISTS idx_coin_logs_user_id;` (Finding #14, superseded by composite index)

## Tier 2: Avatar Screen Refactor (Findings #5–#6)

### New file: `lib/presentation/providers/avatar_provider.dart`

Add `AvatarController` as a `StateNotifier` (or extend existing provider file if avatar providers already live there). Methods:
- `setBase(baseId)` → calls `SetAvatarBaseUseCase`, then `refreshProfileOnly()`
- `equipItem(itemId)` → calls `EquipAvatarItemUseCase`, then `refreshProfileOnly()`
- `unequipItem(itemId)` → calls `UnequipAvatarItemUseCase`, then `refreshProfileOnly()`
- `buyItem(itemId)` → calls `BuyAvatarItemUseCase`, then `refreshProfileOnly()` + invalidate avatar providers

State: `AsyncValue<void>` or a dedicated state class with `isMutating` flag.

### Modify: `avatar_customize_screen.dart`

Replace direct `ref.read(xxxUseCaseProvider)` calls with `ref.read(avatarControllerProvider.notifier).xxx()`. Remove `_isMutating` local state — controller handles it.

Replace all `ref.invalidate(userControllerProvider)` with controller's `refreshProfileOnly()` calls.

## Tier 2: Streak Freeze UX (Finding #7)

### Modify: `top_navbar.dart` + `streak_status_dialog.dart`

Change `onBuyFreeze` callback from `VoidCallback` to `Future<bool> Function()` (or keep VoidCallback but make dialog stateful).

Approach: Make `StreakStatusDialog` a `ConsumerStatefulWidget`. On buy:
1. Set local `_isLoading = true`, rebuild
2. `await ref.read(userControllerProvider.notifier).buyStreakFreeze()`
3. If success: pop dialog
4. If failure: show error snackbar, set `_isLoading = false`

This requires `buyStreakFreeze()` to return a failure message (not just `bool`). Change return type to `Future<Either<Failure, BuyFreezeResult>>` or `Future<String?>` (null = success, string = error).

## Tier 2: Dead Code Cleanup (Findings #8–#10)

### Delete files
- `lib/domain/usecases/card/get_user_coins_usecase.dart`
- `lib/domain/usecases/card/get_cards_by_category_usecase.dart` (verify unused first)

### Remove from providers
- `getUserCoinsUseCaseProvider` from `usecase_providers.dart`
- `getCardsByCategoryUseCaseProvider` from `usecase_providers.dart`
- `collectionByCategoryProvider` from `card_provider.dart`
- `filteredCatalogProvider` + its `selectedCategoryProvider` from `card_provider.dart`

### Remove from repositories
- `getUserCoins()` from `CardRepository` interface and `SupabaseCardRepository`
- `getCardsByCategory()` from `CardRepository` interface and `SupabaseCardRepository`

## Tier 3: Minor Fix

### Pack opening loading text (Finding #12)

In `pack_opening_screen.dart`, split `PackOpeningPhase.buying` and `PackOpeningPhase.opening` in the switch case. Show "Buying pack..." for buying phase, "Opening pack..." for opening phase.

## Deferred (Not Fixing)

- #11: Generic error snackbar distinction — cosmetic, correct behavior
- #15: Pack cost configurability — feature request, not a bug
- #16: Badge checks after avatar purchase — no badge conditions exist for this
- #17: Linear scan in card collection — negligible with 96 cards
- #18: Unused `BuyPackResult.coinsSpent` field — harmless, removing would break model contract
