# Card Collection

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Bug | `open_card_pack` RPC does not return `image_url` in JSONB — pack reveal always uses local asset path, not Supabase Storage URL | Medium | Fixed |
| 2 | Bug | Admin `user_edit_screen.dart:55` orders by `obtained_at` — column is actually `first_obtained_at`; order silently ignored | Medium | Fixed |
| 3 | Edge Case | `card_collection_screen.dart:285` `firstWhere` has no `orElse` — could throw `StateError` if provider data races | Medium | Fixed |
| 4 | Idempotency | `buy_card_pack` coin log has no `source_id` — client retry on timeout could double-charge (mitigated by `FOR UPDATE` lock serialization) | Medium | Fixed |
| 5 | Dead Code | `collectionProgressProvider` (card_provider.dart:86) defined but never consumed | Low | Fixed |
| 6 | Dead Code | `CardSummaryRow` widget (card_reveal_effects.dart:194) defined but never used | Low | Fixed |
| 7 | Dead Code | `_buildFallbackBackground(getGradient:)` always called with `true` — `false` branch unreachable | Low | Fixed |
| 8 | Dead Code | `pityTriggered` field propagated RPC → model → entity → `PackResult` but never read in UI | Low | Skipped (kept for future use) |
| 9 | Dead Code | `CardListScreen` (card_list_screen.dart:22) never routed to — only kept alive for provider imports | Low | Fixed |
| 10 | Dead Code | `daily_quest_pack_claims` table + RPCs superseded by `daily_quest_bonus_claims` | Low | TODO |
| 11 | Code Quality | `_rarityColor()` duplicated identically in 3 admin files | Low | TODO |
| 12 | Code Quality | `MythCardModel.parseRarity()` duplicates `CardRarity.fromDbValue()` from shared package | Low | TODO |
| 13 | Code Quality | Inconsistent sort direction in `sortedCollectionByCategoryProvider` — owned descending, unowned ascending by rarity — undocumented | Low | TODO |
| 14 | RLS | `pack_purchases` INSERT policy allows direct client inserts (audit data pollution, no real harm) | Low | TODO |
| 15 | Infra | `'card-images'` storage bucket hard-coded — no `StorageBuckets` constant class | Low | TODO |
| 16 | Infra | Card delete in admin doesn't remove image from `card-images` Storage — orphaned blobs | Low | TODO |
| 17 | Infra | Image storage path tied to card name — renaming creates orphaned blobs | Low | TODO |
| 18 | UX | Dashboard "Koleksiyon" stat only counts badges, not myth cards | Low | TODO |
| 19 | Freshness | `cardCatalogProvider` never invalidated — stale until app restart if admin deactivates cards | Low | TODO |

### Checklist Result (post-fix)

- Architecture Compliance: **PASS** — Clean Screen → Provider → UseCase → Repository layering; JSON in models only; `DbTables.x` and `RpcFunctions.x` used throughout
- Code Quality: **3 remaining** — duplicated `_rarityColor` (#11), duplicated rarity parser (#12), undocumented asymmetric sort (#13)
- Dead Code: **1 remaining** — `pityTriggered` kept for future use (#8); dead table `daily_quest_pack_claims` (#10). Others fixed.
- Database & Security: **PASS** — Auth guards present; `buy_card_pack` now has idempotency key; `FOR UPDATE` serialization; 1 minor RLS over-permissiveness on `pack_purchases` INSERT (#14)
- Edge Cases & UX: **PASS** — `firstOrNull` guard added (#3); `image_url` now returned in pack reveal (#1)
- Performance: **PASS** — No N+1; 96-card catalog is small; provider lifecycle correct (global cache + autoDispose on controller)
- Cross-System Integrity: **PASS** — Coin deduction audited in `coin_logs` with optional idempotency key; no XP/badge triggers (by design); daily quest integration correct via `unopened_packs` increment

---

## Overview

Card Collection is a gamification feature where students spend coins to buy card packs, then open them to reveal and collect mythology-themed cards. The system has 96 cards across 8 myth categories, with 4 rarity tiers and a pity mechanic that guarantees a legendary card after 14 packs without one. The admin manages the card catalog (CRUD + image upload). There is no teacher surface.

## Data Model

### Tables

**`myth_cards`** — Card catalog (96 rows)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| card_no | VARCHAR(10) UNIQUE | `M-001` through `M-096` |
| name | VARCHAR(100) | |
| category | VARCHAR(50) | CHECK constraint: 8 values |
| rarity | VARCHAR(20) | `common`, `rare`, `epic`, `legendary` |
| power | INTEGER | |
| special_skill | VARCHAR(200) | nullable |
| description | TEXT | nullable |
| category_icon | VARCHAR(10) | emoji, nullable |
| is_active | BOOLEAN | default `true`; inactive cards excluded from pack rolls and student views |
| image_url | VARCHAR(500) | nullable; Supabase Storage URL |

**`user_cards`** — Per-user ownership
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK → profiles | ON DELETE CASCADE |
| card_id | UUID FK → myth_cards | ON DELETE CASCADE |
| quantity | INTEGER | incremented on duplicates |
| first_obtained_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| UNIQUE(user_id, card_id) | | prevents duplicate rows; quantity used instead |

**`user_card_stats`** — Pity counter and totals (1 row per user)
| Column | Type | Notes |
|--------|------|-------|
| user_id | UUID PK FK → profiles | |
| packs_since_legendary | INTEGER | pity counter; resets to 0 on any legendary |
| total_packs_opened | INTEGER | lifetime total |
| total_unique_cards | INTEGER | recomputed each open via `COUNT(*)` |

**`pack_purchases`** — Audit log (append-only)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK → profiles | |
| cost | INTEGER | 100 for buy; 0 for inventory opens |
| card_ids | UUID[] | the 3 cards rolled |
| pity_counter_at_purchase | INTEGER | snapshot of pity counter at time of open |
| created_at | TIMESTAMPTZ | |

### Key Relationships

```
profiles.coins → buy_card_pack → profiles.unopened_packs → open_card_pack → user_cards
                                                                           → user_card_stats
                                                                           → pack_purchases
myth_cards (catalog) ← user_cards.card_id (FK)
```

### RPC Functions

| Function | Purpose | Auth |
|----------|---------|------|
| `buy_card_pack(p_user_id, p_pack_cost, p_idempotency_key)` | Deduct coins, increment `unopened_packs`, log to `coin_logs` with idempotency key | `auth.uid()` check |
| `open_card_pack(p_user_id)` | Decrement `unopened_packs`, roll 3 cards (with `image_url`), upsert `user_cards`, update stats, log to `pack_purchases` | `auth.uid()` check |

### RLS Policies

| Table | Policy | Type |
|-------|--------|------|
| myth_cards | Anyone can read active cards (`is_active = true`) | SELECT |
| myth_cards | Admins can manage cards | ALL (admin) |
| user_cards | Users can manage own cards | ALL (own rows) |
| user_cards | Users can view classmate cards (same school) | SELECT |
| user_card_stats | Users can manage own stats | ALL (own rows) |
| pack_purchases | Users can view own purchases | SELECT |
| pack_purchases | Users can insert own purchases | INSERT (over-permissive — see Finding #14) |

## Surfaces

### Admin

**Entry point:** Dashboard → Koleksiyon → "Mitoloji Kartları" tab (`CollectiblesScreen(initialTab: 1)`)

**Card CRUD:**
- **List view:** Category-filtered grid showing card image, name, rarity badge, power, card_no. Filter via `CardCategory` dropdown.
- **Create:** Auto-generates next `card_no` (M-XXX). Fields: name, category (dropdown), rarity (dropdown), power, special_skill, description, category_icon (emoji), is_active toggle.
- **Edit:** Same form, pre-populated from DB.
- **Delete:** Confirmation dialog with warning about affected users. Hard-deletes from `myth_cards` (cascades to `user_cards`). Does NOT remove image from Storage.
- **Image upload:** `FilePicker` → Supabase Storage bucket `card-images`. Path = card name. Stores public URL in `image_url`.

**Limitations (no admin UI exists for):**
- Pack cost configuration (hard-coded 100 in RPC default)
- Per-card ownership/collection analytics
- Bulk activate/deactivate
- Image deletion from Storage

**Key files:**
- `owlio_admin/lib/features/cards/screens/card_edit_screen.dart`
- `owlio_admin/lib/features/collectibles/screens/collectibles_screen.dart`

### Student

**Entry points:**
- Profile screen → Card Collection section (top 5 cards + progress bar) → tap → `CardCollectionScreen`
- Navigation → Cards tab → `PackOpeningScreen`

**Collection screen** (`CardCollectionScreen`):
- Grid view organized by 8 myth categories
- Each category shows: icon + name header, then cards sorted by rarity (owned: highest first, unowned: lowest first)
- Owned cards: full art with rarity-colored border, "×N" quantity badge
- Unowned cards: silhouette/locked state with "?" placeholder
- Category progress: "X/12" indicator per category
- Tap owned card → detail view showing name, power, special_skill, description, rarity, quantity

**Pack opening screen** (`PackOpeningScreen`):
- Shows coin balance and unopened pack count
- **BUY PACK** button (100 coins): disabled when insufficient coins; shows "Complete daily quests or read books to get packs!" hint
- **OPEN PACK** button: disabled when `packs == 0`

**Pack opening flow** — 5-phase state machine:
1. **idle** — buttons visible, can buy or open
2. **buying** — loading spinner, "Buying pack..." text; transitions back to idle with success overlay (2s)
3. **opening** → **glowing** — RPC call, then `PackGlowWidget` plays rarity-based glow animation (1500ms)
4. **revealing** — 3 face-down cards shown; user taps each to flip (3D Matrix4 rotation). Legendary cards trigger `LegendaryRevealOverlay` (full-screen, tap to dismiss)
5. **complete** — all cards revealed; "OPEN AGAIN" (if packs remain) or "DONE" button. Done resets state and invalidates card providers.

**Key files:**
- `lib/presentation/screens/cards/card_collection_screen.dart`
- `lib/presentation/screens/cards/pack_opening_screen.dart`
- `lib/presentation/providers/card_provider.dart`

### Teacher

N/A — no teacher surface for card collection.

## Business Rules

1. **Pack cost:** 100 coins (hard-coded in RPC default parameter and `AppConstants.packCost`)
2. **Cards per pack:** 3
3. **Total catalog:** 96 cards = 8 categories × 12 cards each
4. **Card numbers:** `M-001` through `M-096` (sequential within categories)
5. **Rarity distribution in catalog:** Common, Rare, Epic, Legendary (distribution set per card in seed data)
6. **Slot 1-2 drop rates:** Common 60%, Rare 25%, Epic 12%, Legendary 3%
7. **Slot 3 guaranteed Rare+:** Rare 60%, Epic 30%, Legendary 10%
8. **Pity system:** After 14 consecutive packs without a legendary → slot 3 forced legendary
9. **Pity counter reset:** Resets to 0 when ANY card in the pack is legendary (including natural rolls on slots 1-2)
10. **No duplicate cards within a single pack:** `mc.id != ALL(v_card_ids)` filter
11. **Duplicate cards across packs:** Increment `quantity` on existing `user_cards` row (UPSERT)
12. **Fallback roll:** If no card of target rarity exists (e.g., all legendaries already in pack), falls back to any active card not already in the pack
13. **Pack sources:** (a) Buy with 100 coins, (b) daily quest reward type `card_pack`, (c) all-quests-complete bonus via `claim_daily_bonus`
14. **No XP or badge triggers:** Card collection is a pure coin-sink; no XP awarded for buying/opening packs
15. **Coin deduction is server-only:** `REVOKE UPDATE(coins, unopened_packs) ON profiles FROM authenticated` prevents client-side manipulation
16. **Buy idempotency:** Client generates UUID v4 per buy request → passed as `p_idempotency_key` → stored as `coin_logs.source_id` → duplicate key returns no-op with `coins_spent = 0`
17. **Inactive cards:** Hidden from student catalog view (RLS: `is_active = true`), excluded from pack rolls
18. **Cross-school card viewing:** Users in the same school can view each other's card collections (RLS policy)

## Cross-System Interactions

### Coin Economy → Card Collection
```
coins earned (XP=coins 1:1) → profiles.coins
  → buy_card_pack RPC (with UUID v4 idempotency key)
    → coin_logs idempotency check (source_id = key)
    → profiles.coins -= 100, profiles.unopened_packs += 1
    → coin_logs INSERT (source: 'pack_purchase', source_id: key)
```

### Daily Quest → Card Collection
```
quest type 'card_pack' completed → profiles.unopened_packs += reward_amount (direct UPDATE, no coin_logs)
all quests complete → claim_daily_bonus RPC → profiles.unopened_packs += 1, daily_quest_bonus_claims INSERT
```

### Card Collection → Profile
```
open_card_pack → user_cards UPSERT, user_card_stats UPDATE
  → refreshProfileOnly() updates userCoinsProvider + unopenedPacksProvider
  → profile screen reads userCardStatsProvider for collection progress display
```

### What Card Collection Does NOT Trigger
- No XP awards
- No badge checks
- No streak updates
- No assignment progress

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Insufficient coins | Buy button disabled; hint text shown; RPC raises `'Insufficient coins'` if called directly |
| Zero packs | Open button disabled (neutral variant, null onPressed) |
| All 96 cards owned | New pack opens still work — duplicates increment quantity |
| All cards of target rarity in pack | Fallback to any active card not already in current pack |
| No active cards at all | `NOT FOUND` after fallback — RPC would error (shouldn't happen with 96 seeded cards) |
| Pity at exactly 14 | Slot 3 forced legendary; counter resets to 0 |
| Network timeout on buy | Client generates UUID v4 idempotency key per request; RPC checks `coin_logs` for duplicate `source_id` and returns no-op if found |
| Admin deactivates card mid-session | Catalog provider not invalidated — student sees stale card until app restart; pack rolls correctly exclude it server-side |
| Admin deletes owned card | `user_cards` row cascade-deleted; student loses card |
| Card image not uploaded | Both collection screen and pack reveal fall back to `cardAssetPath(name)` → `assets/images/cards/{name}.png` when `image_url` is null |

## Test Scenarios

- [ ] **Happy path:** Buy a pack with 100+ coins → pack added to inventory → open pack → 3 cards revealed → cards appear in collection
- [ ] **Empty state:** Fresh user with 0 cards → collection shows all 96 locked → category progress all "0/12"
- [ ] **Insufficient coins:** User with < 100 coins → BUY PACK button disabled → hint text visible
- [ ] **Zero packs:** User with 0 unopened packs → OPEN PACK button disabled
- [ ] **Duplicate card:** Open multiple packs → receive same card twice → quantity increments (shows "×2" badge)
- [ ] **Pity mechanic:** Open 15 packs without legendary → 15th pack slot 3 guaranteed legendary
- [ ] **Legendary reveal:** Open pack containing legendary → glow animation → legendary card flip → full-screen `LegendaryRevealOverlay`
- [ ] **Daily quest pack:** Complete a `card_pack` quest → unopened packs increment without coin deduction
- [ ] **Bonus pack:** Complete all daily quests → claim bonus → unopened packs increment
- [ ] **Coin balance sync:** After buying pack → coin balance in header reflects deduction immediately
- [ ] **Collection progress on profile:** Profile screen shows correct X/96 progress bar and top 5 cards
- [ ] **Admin create card:** Create new card with image → appears in student catalog (after app restart)
- [ ] **Admin deactivate card:** Toggle `is_active` off → card excluded from new pack rolls (server-side); student catalog stale until restart
- [ ] **Admin delete card:** Delete card → student loses that card (cascade delete)

## Key Files

### App (Student)
| Layer | File |
|-------|------|
| Entities | `lib/domain/entities/card.dart` |
| Repository interface | `lib/domain/repositories/card_repository.dart` |
| UseCases | `lib/domain/usecases/card/buy_pack_usecase.dart`, `open_pack_usecase.dart`, `get_all_cards_usecase.dart`, `get_user_cards_usecase.dart`, `get_user_card_stats_usecase.dart` |
| Models | `lib/data/models/card/myth_card_model.dart`, `pack_result_model.dart`, `buy_pack_result_model.dart`, `user_card_model.dart`, `user_card_stats_model.dart` |
| Repository impl | `lib/data/repositories/supabase/supabase_card_repository.dart` |
| Providers | `lib/presentation/providers/card_provider.dart` |
| Screens | `lib/presentation/screens/cards/card_collection_screen.dart`, `pack_opening_screen.dart` |
| Widgets | `lib/presentation/widgets/cards/myth_card_widget.dart`, `locked_card_widget.dart`, `card_flip_widget.dart`, `card_reveal_effects.dart`, `pack_glow_widget.dart`, `coin_badge.dart` |

### Admin
| Layer | File |
|-------|------|
| Providers | `owlio_admin/lib/features/cards/providers/card_providers.dart` |
| Card CRUD | `owlio_admin/lib/features/cards/screens/card_edit_screen.dart` |
| Collection tab | `owlio_admin/lib/features/collectibles/screens/collectibles_screen.dart` |

### Shared Package
| File | Contents |
|------|----------|
| `packages/owlio_shared/lib/src/enums/card_rarity.dart` | 4 rarities with `dbValue`/`fromDbValue` |
| `packages/owlio_shared/lib/src/enums/card_category.dart` | 8 myth categories with `dbValue`/`fromDbValue` |
| `packages/owlio_shared/lib/src/constants/tables.dart` | `mythCards`, `userCards`, `userCardStats`, `packPurchases` |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | `buyCardPack`, `openCardPack` |

### Database
| Migration | Purpose |
|-----------|---------|
| `20260209000003_create_card_catalog.sql` | `myth_cards` table + indexes |
| `20260209000004_seed_myth_cards.sql` | 96 card seed data |
| `20260209000005_create_user_cards.sql` | `user_cards`, `user_card_stats`, `pack_purchases` tables + RLS |
| `20260209000007_add_pack_inventory.sql` | Original `buy_card_pack` + `open_card_pack` RPCs (superseded) |
| `20260213000002_fix_card_rls.sql` | Fixed `user_cards` RLS policies |
| `20260322000002_add_myth_card_image_url.sql` | Added `image_url` column + bulk update |
| `20260328100001_coin_security_hardening.sql` | Auth guards + column-level REVOKE (superseded by below) |
| `20260328200001_card_audit_fixes.sql` | **Current live** `open_card_pack` with `image_url` + `buy_card_pack` with idempotency key |

## Known Issues & Tech Debt

1. ~~`open_card_pack` missing `image_url` in JSONB response~~ — **Fixed** in `20260328200001`.
2. ~~`buy_card_pack` has no idempotency key~~ — **Fixed** in `20260328200001` with `p_idempotency_key UUID DEFAULT NULL`.
3. **`daily_quest_pack_claims` table is dead schema** — Superseded by `daily_quest_bonus_claims`. Pending drop migration.
4. ~~Dead code accumulation~~ — **Fixed**: `collectionProgressProvider`, `CardSummaryRow`, `CardListScreen` deleted.
5. **Admin `_rarityColor()` duplicated 3 times** — Should be a shared utility or extension on `CardRarity`.
6. **No admin pack cost configuration** — Cost is hard-coded as `DEFAULT 100` in RPC; no system_settings entry exists.
7. **Card image orphaning** — Renaming or deleting a card does not clean up Storage blobs.
8. ~~Admin orders `user_cards` by `obtained_at`~~ — **Fixed**: corrected to `first_obtained_at`.
