# Card Collection Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 8 findings from the Card Collection audit (4 bugs + 4 dead code cleanups).

**Architecture:** Tier A fixes 4 real bugs (missing `image_url` in RPC, wrong column name, unsafe `firstWhere`, missing idempotency key). Tier B removes 4 dead code items (unused provider, widget, parameter, dead screen). All changes are independent — no cross-task dependencies.

**Tech Stack:** Supabase SQL migrations, Dart/Flutter, Riverpod

---

### Task 1: Add `image_url` to `open_card_pack` RPC response

**Finding #1:** `open_card_pack` builds card JSONB without `image_url`. Pack reveal always falls back to local asset path.

**Files:**
- Create: `supabase/migrations/20260328200001_card_audit_fixes.sql`

- [ ] **Step 1: Create migration adding `image_url` to JSONB**

```sql
-- Card Collection audit fix: include image_url in open_card_pack JSONB response
-- Finding #1: pack reveal uses local asset fallback because image_url is missing

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
            'image_url', v_selected_card.image_url,
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
```

The only change from the previous version is the addition of `'image_url', v_selected_card.image_url` on the line after `'description'` in the `jsonb_build_object` call.

- [ ] **Step 2: Dry-run migration**

Run: `supabase db push --dry-run`
Expected: Shows the `CREATE OR REPLACE FUNCTION` statement, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully.

---

### Task 2: Fix admin `obtained_at` column name typo

**Finding #2:** `user_edit_screen.dart:55` orders by non-existent column `obtained_at` — should be `first_obtained_at`.

**Files:**
- Modify: `owlio_admin/lib/features/users/screens/user_edit_screen.dart:55`

- [ ] **Step 1: Fix column name**

Change line 55 from:
```dart
      .order('obtained_at', ascending: false));
```
to:
```dart
      .order('first_obtained_at', ascending: false));
```

- [ ] **Step 2: Verify no other `obtained_at` references exist**

Run: `grep -r "obtained_at" owlio_admin/lib/`
Expected: No results (or only `first_obtained_at` references).

---

### Task 3: Add `orElse` to `firstWhere` in collection screen

**Finding #3:** `card_collection_screen.dart:285` — `firstWhere` can throw `StateError` if `ownedCardIdsProvider` and `userCardsProvider` have a data race.

**Files:**
- Modify: `lib/presentation/screens/cards/card_collection_screen.dart:284-291`

- [ ] **Step 1: Replace `firstWhere` with null-safe pattern**

Change:
```dart
                  ? (() {
                      final userCard = userCards.firstWhere((uc) => uc.cardId == card.id);
                      return MythCardWidget(
                        card: card,
                        quantity: userCard.quantity,
                        onTap: () => onCardTap(card, userCard.quantity),
                      );
                    })()
```
to:
```dart
                  ? (() {
                      final userCard = userCards.where((uc) => uc.cardId == card.id).firstOrNull;
                      if (userCard == null) {
                        return LockedCardWidget(
                          card: card,
                          onTap: () => onLockedTap(card),
                        );
                      }
                      return MythCardWidget(
                        card: card,
                        quantity: userCard.quantity,
                        onTap: () => onCardTap(card, userCard.quantity),
                      );
                    })()
```

---

### Task 4: Add idempotency key to `buy_card_pack`

**Finding #4:** Client retry on network timeout can double-charge because `coin_logs` entry has no `source_id`.

**Files:**
- Modify: `supabase/migrations/20260328200001_card_audit_fixes.sql` (append to same migration file)
- Modify: `lib/domain/repositories/card_repository.dart:17`
- Modify: `lib/data/repositories/supabase/supabase_card_repository.dart:84-92`
- Modify: `lib/domain/usecases/card/buy_pack_usecase.dart`
- Modify: `lib/presentation/providers/card_provider.dart:202-203`

- [ ] **Step 1: Add `p_idempotency_key` to `buy_card_pack` RPC**

Append to `supabase/migrations/20260328200001_card_audit_fixes.sql`:

```sql
-- Finding #4: add idempotency key to buy_card_pack to prevent double-charge on retry

CREATE OR REPLACE FUNCTION buy_card_pack(
    p_user_id UUID,
    p_pack_cost INTEGER DEFAULT 100,
    p_idempotency_key UUID DEFAULT NULL
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

    -- Idempotency check: if this key was already used, return current state
    IF p_idempotency_key IS NOT NULL AND EXISTS (
        SELECT 1 FROM coin_logs
        WHERE user_id = p_user_id AND source = 'pack_purchase' AND source_id = p_idempotency_key
    ) THEN
        RETURN jsonb_build_object(
            'coins_spent', 0,
            'coins_remaining', v_current_coins,
            'unopened_packs', v_new_packs
        );
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

    -- Log coin transaction with idempotency key
    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, -p_pack_cost, v_new_coins, 'pack_purchase', p_idempotency_key, 'Card pack purchased (stored)');

    RETURN jsonb_build_object(
        'coins_spent', p_pack_cost,
        'coins_remaining', v_new_coins,
        'unopened_packs', v_new_packs
    );
END;
$$;
```

- [ ] **Step 2: Update repository interface**

In `lib/domain/repositories/card_repository.dart`, change line 17:
```dart
  Future<Either<Failure, BuyPackResult>> buyPack(String userId, {int cost = 100});
```
to:
```dart
  Future<Either<Failure, BuyPackResult>> buyPack(String userId, {int cost = 100, String? idempotencyKey});
```

- [ ] **Step 3: Update repository implementation**

In `lib/data/repositories/supabase/supabase_card_repository.dart`, change the `buyPack` method signature and params:
```dart
  @override
  Future<Either<Failure, BuyPackResult>> buyPack(String userId, {int cost = 100, String? idempotencyKey}) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.buyCardPack,
        params: {
          'p_user_id': userId,
          'p_pack_cost': cost,
          if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
        },
      );
```

- [ ] **Step 4: Update use case to accept and forward idempotency key**

In `lib/domain/usecases/card/buy_pack_usecase.dart`, update `BuyPackParams` and the call:
```dart
class BuyPackParams {
  const BuyPackParams({required this.userId, this.cost = 100, this.idempotencyKey});
  final String userId;
  final int cost;
  final String? idempotencyKey;
}

class BuyPackUseCase implements UseCase<BuyPackResult, BuyPackParams> {
  const BuyPackUseCase(this._repository);
  final CardRepository _repository;

  @override
  Future<Either<Failure, BuyPackResult>> call(BuyPackParams params) {
    return _repository.buyPack(params.userId, cost: params.cost, idempotencyKey: params.idempotencyKey);
  }
}
```

- [ ] **Step 5: Generate UUID in controller**

In `lib/presentation/providers/card_provider.dart`, add import and update the `buyPack` method:

Add at top of file (after existing imports):
```dart
import 'package:uuid/uuid.dart';
```

Change line 202-203 from:
```dart
    final useCase = _ref.read(buyPackUseCaseProvider);
    final result = await useCase(BuyPackParams(userId: userId, cost: cost));
```
to:
```dart
    final useCase = _ref.read(buyPackUseCaseProvider);
    final idempotencyKey = const Uuid().v4();
    final result = await useCase(BuyPackParams(userId: userId, cost: cost, idempotencyKey: idempotencyKey));
```

- [ ] **Step 6: Verify `uuid` package is already a dependency**

Run: `grep "uuid:" pubspec.yaml`
Expected: `uuid` should already be listed. If not, run `flutter pub add uuid`.

- [ ] **Step 7: Dry-run and push migration**

Run: `supabase db push --dry-run` then `supabase db push`

---

### Task 5: Remove dead `collectionProgressProvider`

**Finding #5:** Defined at `card_provider.dart:86-91`, never consumed.

**Files:**
- Modify: `lib/presentation/providers/card_provider.dart:85-91`

- [ ] **Step 1: Delete the provider**

Remove lines 85-91:
```dart
/// Collection progress: unique owned / total catalog
final collectionProgressProvider = Provider<double>((ref) {
  final owned = ref.watch(ownedCardIdsProvider).length;
  final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
  if (catalog.isEmpty) return 0.0;
  return owned / catalog.length;
});
```

- [ ] **Step 2: Verify no references**

Run: `grep -r "collectionProgressProvider" lib/`
Expected: No results.

---

### Task 6: Remove dead `CardSummaryRow` widget

**Finding #6:** Defined at `card_reveal_effects.dart:193-282`, never used.

**Files:**
- Modify: `lib/presentation/widgets/cards/card_reveal_effects.dart:192-282`

- [ ] **Step 1: Delete `CardSummaryRow` class**

Remove from line 192 (the blank line before the doc comment) to line 282 (end of file). The file should end after `LegendaryRevealOverlay`'s closing brace at line 191.

- [ ] **Step 2: Remove unused imports if any**

Check if removing `CardSummaryRow` makes any imports unused (it uses `CardColors`, `AppColors`, `GoogleFonts`, `MythCard`). These are also used by the remaining widgets (`NewCardBadge`, `DuplicateCountBadge`, `LegendaryRevealOverlay`), so no imports should become unused.

---

### Task 7: Simplify `_buildFallbackBackground` parameter

**Finding #7:** `getGradient` parameter always `true` at all 3 callsites — `false` branch is unreachable.

**Files:**
- Modify: `lib/presentation/widgets/cards/myth_card_widget.dart:61,343,350,354-370`

- [ ] **Step 1: Remove parameter from method signature and callsites**

Change the method definition (line 354) from:
```dart
  Widget _buildFallbackBackground({required bool getGradient}) {
    if (!getGradient) return const SizedBox.shrink();
    return Container(
```
to:
```dart
  Widget _buildFallbackBackground() {
    return Container(
```

Update all 3 callsites from `_buildFallbackBackground(getGradient: true)` to `_buildFallbackBackground()`:
- Line 61
- Line 343
- Line 350

---

### Task 8: Extract admin card providers from dead `CardListScreen` file

**Finding #9:** `CardListScreen` is dead code but its file hosts `mythCardsProvider` and `cardCategoryFilterProvider` which are imported by 2 other files.

**Files:**
- Create: `owlio_admin/lib/features/cards/providers/card_providers.dart`
- Modify: `owlio_admin/lib/features/cards/screens/card_list_screen.dart` (delete entire file)
- Modify: `owlio_admin/lib/features/cards/screens/card_edit_screen.dart:10`
- Modify: `owlio_admin/lib/features/collectibles/screens/collectibles_screen.dart:8`

- [ ] **Step 1: Create new provider file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading all myth cards
final mythCardsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.mythCards)
      .select()
      .order('card_no');
  return List<Map<String, dynamic>>.from(response);
});

/// Filter by category
final cardCategoryFilterProvider = StateProvider<CardCategory?>((ref) => null);
```

- [ ] **Step 2: Update imports in `card_edit_screen.dart`**

Change line 10 from:
```dart
import 'card_list_screen.dart';
```
to:
```dart
import '../providers/card_providers.dart';
```

- [ ] **Step 3: Update imports in `collectibles_screen.dart`**

Change line 8 from:
```dart
import '../../cards/screens/card_list_screen.dart';
```
to:
```dart
import '../../cards/providers/card_providers.dart';
```

- [ ] **Step 4: Delete `card_list_screen.dart`**

Delete the entire file: `owlio_admin/lib/features/cards/screens/card_list_screen.dart`

- [ ] **Step 5: Verify build**

Run: `cd owlio_admin && flutter analyze lib/`
Expected: No errors related to card imports.

---

### Task 9: Run `dart analyze` and update spec

**Files:**
- Modify: `docs/specs/15-card-collection.md` (update finding statuses)

- [ ] **Step 1: Analyze main app**

Run: `dart analyze lib/`
Expected: No new errors.

- [ ] **Step 2: Analyze admin app**

Run: `cd owlio_admin && dart analyze lib/`
Expected: No new errors.

- [ ] **Step 3: Update finding statuses in spec**

In `docs/specs/15-card-collection.md`, change the Status column from `TODO` to `Fixed` for findings #1, #2, #3, #4, #5, #6, #7, #9.

- [ ] **Step 4: Commit all changes**

```bash
git add -A
git commit -m "fix: Card Collection audit — 8 findings fixed

- Add image_url to open_card_pack RPC JSONB response (#1)
- Fix admin obtained_at → first_obtained_at column name (#2)
- Add orElse guard to firstWhere in collection screen (#3)
- Add idempotency key to buy_card_pack RPC (#4)
- Remove dead collectionProgressProvider (#5)
- Remove dead CardSummaryRow widget (#6)
- Remove unreachable getGradient parameter (#7)
- Extract admin card providers, delete dead CardListScreen (#9)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
