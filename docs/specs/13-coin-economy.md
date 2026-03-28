# Coin Economy

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Security | `profiles` UPDATE RLS policy has no column restriction — any authenticated user can directly `UPDATE profiles SET coins = 999999` on their own row, bypassing all RPC controls | Critical | Fixed |
| 2 | Security | `award_coins_transaction` and `spend_coins_transaction` have no `auth.uid()` check — any authenticated user can award/spend coins for any other user | Critical | Fixed |
| 3 | Security | `buy_card_pack` RPC has no `auth.uid()` check — accepts arbitrary `p_user_id`, allowing any authenticated user to spend another user's coins | Critical | Fixed |
| 4 | Security | `open_card_pack` RPC has no `auth.uid()` check — same pattern as `buy_card_pack` | Critical | Fixed |
| 5 | Architecture | `AvatarCustomizeScreen` calls UseCases directly (`ref.read(buyAvatarItemUseCaseProvider)`) instead of going through a controller provider — violates Screen → Provider → UseCase rule | Medium | Fixed |
| 6 | Code Quality | Avatar screen uses `ref.invalidate(userControllerProvider)` instead of `refreshProfileOnly()` — triggers full provider restart including unnecessary streak RPC call on every avatar mutation | Medium | Fixed |
| 7 | Edge Case | Streak freeze purchase has no loading state and no error feedback — dialog pops before `buyStreakFreeze()` completes, result is fire-and-forget | Medium | Fixed |
| 8 | Dead Code | `GetUserCoinsUseCase`, `getUserCoinsUseCaseProvider`, and `CardRepository.getUserCoins()` are never called — coin balance is sourced entirely from `userControllerProvider` | Medium | Fixed |
| 9 | Dead Code | `GetCardsByCategoryUseCase` and `getCardsByCategoryUseCaseProvider` are unused — collection screen filters in-memory via `sortedCollectionByCategoryProvider` | Medium | Fixed |
| 10 | Dead Code | `collectionByCategoryProvider` and `filteredCatalogProvider` in `card_provider.dart` are never referenced by any screen | Medium | Fixed |
| 11 | Code Quality | UI never distinguishes `InsufficientFundsFailure` from `ServerFailure` — both produce identical generic error snackbars in avatar and pack purchase flows | Low | Deferred |
| 12 | Edge Case | `PackOpeningScreen` shows "Opening pack..." text during the BUY phase (coin deduction) — should say "Buying pack..." | Low | Fixed |
| 13 | Database | `streak_freeze_count` column has no `CHECK >= 0` constraint, unlike `coins` and `unopened_packs` | Low | Fixed |
| 14 | Database | Redundant `idx_coin_logs_user_id` index superseded by `idx_coin_logs_user_created` composite index | Low | Fixed |
| 15 | Database | Card pack cost (100 coins) is hard-coded in both RPC default parameter and Dart layer — not admin-configurable via `system_settings` | Low | Deferred |
| 16 | Cross-System | Badge checks are not run after avatar item purchase (unlike XP-based flows that always trigger badge check) | Low | Deferred |
| 17 | Performance | `CardCollectionScreen` uses `firstWhere` linear scan inside `ListView.builder` — O(n) per rendered card; should pre-build a `Map<String, UserCard>` | Low | Deferred |
| 18 | Dead Code | `BuyPackResult.coinsSpent` field is populated from RPC but never read in UI | Low | Deferred |

### Checklist Result

- Architecture Compliance: PASS (#5 fixed — AvatarController extracted)
- Code Quality: PASS (#6 fixed; #11 deferred — cosmetic)
- Dead Code: PASS (#8–#10 fixed; #18 deferred — harmless)
- Database & Security: PASS (#1–#4 fixed, #13–#14 fixed; #15 deferred — feature request)
- Edge Cases & UX: PASS (#7 fixed, #12 fixed)
- Performance: 1 deferred (#17 — negligible with 96 cards)
- Cross-System Integrity: 1 deferred (#16 — no badge conditions exist for avatar purchases)

---

## Overview

The Coin Economy is the virtual currency system of Owlio. Coins are earned automatically alongside XP (1:1 ratio — every XP award co-awards the same amount of coins) and spent on three categories: card packs (collectibles), avatar items (customization), and streak freezes (protection). There is no admin surface for coin management — coins flow entirely through automated system rules. The coin balance lives on the `profiles` table and all mutations happen through server-side RPC functions with audit logging to `coin_logs`.

## Data Model

### Tables

**`profiles`** (coin-relevant columns only):

| Column | Type | Constraint | Notes |
|--------|------|-----------|-------|
| `coins` | INTEGER | DEFAULT 0, CHECK >= 0 | Virtual currency balance |
| `unopened_packs` | INTEGER | DEFAULT 0, CHECK >= 0 | Purchased but not yet opened card packs |
| `streak_freeze_count` | INTEGER | DEFAULT 0, CHECK >= 0 | Available streak freezes |

**`coin_logs`** (full audit trail):

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | PK, auto-generated |
| `user_id` | UUID | FK → profiles(id) ON DELETE CASCADE |
| `amount` | INTEGER | Positive = earn, negative = spend |
| `balance_after` | INTEGER | Snapshot of balance after transaction |
| `source` | VARCHAR(50) | Category: `xp_award`, `pack_purchase`, `streak_freeze`, `avatar_purchase`, `quest_reward` |
| `source_id` | UUID | Nullable — links to originating entity for idempotency |
| `description` | TEXT | Human-readable note |
| `created_at` | TIMESTAMPTZ | |

**Indexes:**
- `idx_coin_logs_user_created` — `(user_id, created_at DESC)` — user history queries
- `idx_coin_logs_idempotent` — `UNIQUE (user_id, source, source_id) WHERE source_id IS NOT NULL` — prevents duplicate awards

### Key Relationships

- `profiles.coins` is the single source of truth for balance
- `coin_logs` is append-only audit trail — every mutation (earn or spend) writes a log row
- All earning flows go through `award_xp_transaction` (which co-awards coins) or `award_coins_transaction` (standalone, for quest rewards)
- All spending flows go through `spend_coins_transaction` or direct SQL in specific RPCs

## Surfaces

### Admin

N/A — No admin coin management screen. Admin touches coins indirectly in two places:
- **Avatar item editor**: Sets `coin_price` on items (controls cost)
- **Quest editor**: Can configure quests with `reward_type = 'coins'` (awards coins without XP)

System settings that affect the coin economy:
| Setting | Default | Purpose |
|---------|---------|---------|
| `streak_freeze_price` | 50 | Coin cost per streak freeze |
| `streak_freeze_max` | 2 | Maximum freezes a user can hold |
| Pack cost | 100 | **Hard-coded** in RPC + Dart, not in system_settings |

### Student

**Earning coins:**
1. **XP co-award (primary)**: Every XP award automatically co-awards the same number of coins. Student does not see a separate "coins earned" event — coins appear alongside XP in the profile.
   - Chapter complete: +50 coins (via +50 XP)
   - Book complete (no quiz): +200 coins (via +200 XP)
   - Inline activity: +25 coins (via +25 XP)
   - Quiz pass: +20 coins (via +20 XP)
   - Vocab session: base + combo bonus coins (via XP)
   - Streak milestone: milestone XP bonus coins (via XP)
2. **Quest reward (secondary)**: Quests configured with `reward_type = 'coins'` award coins-only (no XP) via `award_coins_transaction`.

**Spending coins:**
1. **Card pack** (100 coins): Buy a pack → pack goes to `unopened_packs` inventory → open to reveal 3 cards with rarity-weighted randomness
2. **Avatar item** (variable price): Buy an accessory → auto-equipped → coins deducted
3. **Streak freeze** (50 coins default): Buy a freeze → protects next missed day → max 2 held

**Coin display:**
- `TopNavbar` (global): Shows live coin balance via `userControllerProvider`
- `CoinBadge` widget: Formats numbers >= 10,000 as `X.XK`
- Pack opening screen: Shows balance + "Not enough coins" hint when `coins < 100 && unopenedPacks == 0`

### Teacher

N/A — Teachers do not see individual student coin balances or spending history.

## Business Rules

1. **XP = Coins 1:1**: Every `award_xp_transaction` call adds `p_amount` to both `xp` and `coins` atomically in a single SQL UPDATE. There is no way to earn XP without earning coins, and no way to earn coins without XP (except quest coin rewards).
2. **Balance floor = 0**: The `CHECK (coins >= 0)` constraint prevents overspending. RPC functions also validate before deduction, but the constraint is the database-level safety net.
3. **No balance ceiling**: There is no maximum coin limit. The `CoinBadge` widget formats large numbers but does not cap them.
4. **Idempotency**: Earning operations with a `source_id` are protected by the `idx_coin_logs_idempotent` unique index. Duplicate network requests for the same XP event produce no additional coins. Spending operations (pack buy, avatar buy, freeze buy) do NOT have idempotency keys — duplicate requests can process twice if the user has sufficient balance.
5. **Atomicity**: All coin mutations use `FOR UPDATE` row locks on `profiles` to prevent race conditions. Coin deduction + inventory increment happen in the same SQL transaction.
6. **Audit trail**: Every coin change (positive or negative) writes to `coin_logs` with source categorization and balance snapshot.
7. **Pack cost is static**: 100 coins, hard-coded as a default parameter in `buy_card_pack(p_pack_cost INTEGER DEFAULT 100)` and in Dart as `SupabaseCardRepository.buyPack({int cost = 100})`.
8. **Streak freeze cost is configurable**: Read from `system_settings.streak_freeze_price` at purchase time.
9. **Avatar item cost is per-item**: Set by admin in `avatar_items.coin_price` column.

## Cross-System Interactions

### Earning Chain
```
Any XP-awarding activity
  → UserController.addXP(amount, source, sourceId)
    → AddXPUseCase → supabase.rpc('award_xp_transaction')
      → profiles.xp += amount
      → profiles.coins += amount       ← XP=Coins 1:1
      → profiles.level = recalculate
      → xp_logs INSERT
      → coin_logs INSERT (source = source param)
    → CheckAndAwardBadgesUseCase       ← badge check after XP
    → refreshProfileOnly()             ← UI update
```

### Spending Chains

**Card pack:**
```
PackOpeningController.buyPack()
  → BuyPackUseCase → supabase.rpc('buy_card_pack')
    → profiles.coins -= 100
    → profiles.unopened_packs += 1
    → coin_logs INSERT (source = 'pack_purchase')
  → refreshProfileOnly()
```

**Avatar item:**
```
AvatarCustomizeScreen._buy(item)
  → BuyAvatarItemUseCase → supabase.rpc('buy_avatar_item')
    → spend_coins_transaction(user, price, 'avatar_purchase', itemId)
      → profiles.coins -= price
      → coin_logs INSERT
    → user_avatar_items INSERT
    → auto-equip + cache rebuild
  → ref.invalidate(userControllerProvider)     ← heavier than needed
```

**Streak freeze:**
```
UserController.buyStreakFreeze()
  → BuyStreakFreezeUseCase → supabase.rpc('buy_streak_freeze')
    → spend_coins_transaction(user, price, 'streak_freeze', null)
      → profiles.coins -= price
      → coin_logs INSERT
    → profiles.streak_freeze_count += 1
  → re-fetch profile, update state
```

### Systems that read coin balance
- **TopNavbar**: Displays live balance from `userControllerProvider`
- **PackOpeningScreen**: Gates "Buy Pack" button on `coins >= 100`
- **AvatarCustomizeScreen**: Gates "Buy" button on `coins >= item.coinPrice`
- **StreakStatusDialog**: Gates "Buy Freeze" button on `coins >= streakFreezePrice`

## Edge Cases

| Scenario | Current Behavior |
|----------|-----------------|
| 0 coins, 0 packs | Pack screen shows hint: "Earn coins by completing books and activities" |
| Insufficient coins for pack | Buy button disabled (client-side check) + server returns `insufficient_coins` |
| Insufficient coins for avatar | Server returns `InsufficientFundsFailure`; UI shows generic error snackbar |
| Insufficient coins for freeze | Server returns `insufficient_coins`; **no error shown** (fire-and-forget call) |
| Already own avatar item | Server returns `'Already owned'` as `ServerFailure`; UI shows "Purchase failed: Already owned" |
| Max freezes reached | Server returns `max_freezes_reached`; **no error shown** (same fire-and-forget issue) |
| Double-tap buy pack | `PackOpeningController` has a `_isBuying` guard; only one request fires |
| Double-tap buy avatar | `_isMutating` guard in screen state; only one request fires |
| Double-tap buy freeze | No client-side guard; two requests can fire, second fails on balance check |
| Concurrent earn + spend | `FOR UPDATE` row lock serializes; no phantom reads |
| User deleted | `ON DELETE CASCADE` cleans up all `coin_logs`, `user_cards`, etc. |

## Test Scenarios

- [ ] **Happy path — earn coins via chapter complete**: Complete a chapter, verify XP and coins both increase by 50
- [ ] **Happy path — buy card pack**: With >= 100 coins, tap Buy Pack, verify coins decrease by 100, unopened packs increase by 1
- [ ] **Happy path — buy avatar item**: With sufficient coins, buy an item, verify coins decrease by item price, item appears in inventory and auto-equips
- [ ] **Happy path — buy streak freeze**: With sufficient coins, buy a freeze, verify coins decrease by `streak_freeze_price`, freeze count increases
- [ ] **Empty state — 0 coins, 0 packs**: Navigate to pack screen, verify hint message shown, Buy button disabled
- [ ] **Error — insufficient coins for pack**: With < 100 coins, verify Buy button is disabled
- [ ] **Error — insufficient coins for avatar**: Attempt purchase with low balance, verify error feedback
- [ ] **Error — max freezes reached**: With 2 freezes already, attempt buy, verify rejection
- [ ] **Boundary — exact balance**: With exactly 100 coins, buy pack, verify success and 0 remaining
- [ ] **Cross-system — XP=Coins parity**: After any XP-awarding activity, verify `coin_logs` entry matches `xp_logs` amount
- [ ] **Cross-system — coin balance refresh**: After purchase, verify `TopNavbar` coin display updates
- [ ] **Idempotency — duplicate XP award**: Trigger same chapter complete twice, verify only one coin award
- [ ] **Quest coin reward**: Complete a quest with `reward_type = 'coins'`, verify coins awarded without XP change

## Key Files

### Domain
- `lib/domain/entities/user.dart` — `User.coins`, `User.unopenedPacks`
- `lib/domain/entities/avatar.dart` — `AvatarItem.coinPrice`, `BuyAvatarItemResult`
- `lib/domain/entities/streak_result.dart` — `BuyFreezeResult`
- `lib/domain/usecases/card/buy_pack_usecase.dart` — Pack purchase
- `lib/domain/usecases/avatar/buy_avatar_item_usecase.dart` — Avatar purchase
- `lib/domain/usecases/user/buy_streak_freeze_usecase.dart` — Freeze purchase
- `lib/domain/usecases/user/add_xp_usecase.dart` — XP+coin co-award

### Data
- `lib/data/repositories/supabase/supabase_card_repository.dart` — Card/pack RPC calls
- `lib/data/repositories/supabase/supabase_avatar_repository.dart` — Avatar buy RPC
- `lib/data/repositories/supabase/supabase_user_repository.dart` — XP + freeze RPCs

### Presentation
- `lib/presentation/providers/user_provider.dart` — `UserController` (coin balance source of truth)
- `lib/presentation/providers/card_provider.dart` — `userCoinsProvider`, `PackOpeningController`
- `lib/presentation/screens/cards/pack_opening_screen.dart` — Pack buy/open UI
- `lib/presentation/screens/avatar/avatar_customize_screen.dart` — Avatar shop
- `lib/presentation/widgets/common/top_navbar.dart` — Global coin display
- `lib/presentation/widgets/cards/coin_badge.dart` — Coin formatting widget

### Database
- `supabase/migrations/20260209000001_add_coins_to_profiles.sql` — `coin_logs` table, initial schema
- `supabase/migrations/20260209000002_create_coin_functions.sql` — `award_coins_transaction`, `spend_coins_transaction`
- `supabase/migrations/20260209000007_add_pack_inventory.sql` — `buy_card_pack`, `open_card_pack`
- `supabase/migrations/20260210000004_add_balance_constraints.sql` — CHECK constraints
- `supabase/migrations/20260316000006_coin_idempotency_and_xp_constraint.sql` — Idempotency index + TOCTOU fix
- `supabase/migrations/20260328000004_add_auth_check_to_award_xp.sql` — Auth guard on `award_xp_transaction`

## Known Issues & Tech Debt

1. **Critical security gaps** (#1–#4): `profiles` UPDATE RLS allows direct coin inflation; `buy_card_pack`, `open_card_pack`, `award_coins_transaction`, and `spend_coins_transaction` lack `auth.uid()` verification. Priority fix: add auth guards to all RPCs and restrict `profiles` UPDATE policy to non-monetary columns (or use column-level security).
2. **Avatar screen architecture violation** (#5–#6): Screen calls UseCases directly and uses `invalidate(userControllerProvider)` triggering unintended streak checks. Needs an `AvatarController` StateNotifier mirroring the `PackOpeningController` pattern.
3. **Streak freeze UX gap** (#7): No loading state, no error feedback on purchase. Dialog dismisses before result is known.
4. **Dead code accumulation** (#8–#10, #18): 3 unused UseCases, 2 unused providers, 1 unused entity field. Cleanup needed.
5. **Pack cost not configurable** (#15): Hard-coded 100 coins in both SQL and Dart. Should be a `system_settings` entry like `streak_freeze_price`.
