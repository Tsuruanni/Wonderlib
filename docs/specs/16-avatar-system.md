# Avatar System

## Audit

### Findings

| # | Category | Issue | Severity | Status |
|---|----------|-------|----------|--------|
| 1 | Dead Code | `GetEquippedAvatarUseCase`, its provider (`getEquippedAvatarUseCaseProvider`), and `AvatarRepository.getEquippedAvatar()` are never called — `equippedAvatarProvider` reads directly from user profile cache | Low | Fixed |
| 2 | Dead Code | `preview_url` column on `avatar_items` exists in DB, entity, and model but admin has no field to set it and no consumer reads it distinctly | Medium | Skipped (no harm; not worth migration to drop nullable column) |
| 3 | Security | Storage upload policy (`avatars_authenticated_insert/update`) grants ALL authenticated users write access to `avatars` bucket — students can upload/overwrite avatar asset files | High | Fixed |
| 4 | Code Quality | Error discrimination in `supabase_avatar_repository.dart:108` uses `e.message.contains('Insufficient coins')` string matching — fragile if DB message changes | Low | Skipped (codebase-wide pattern) |
| 5 | Code Quality | `_rarityColor()` duplicated in 3 places: `avatar_customize_screen.dart:63`, `avatar_management_screen.dart:318`, `avatar_item_edit_screen.dart:484` | Low | Fixed |
| 6 | Edge Case | `avatarBasesProvider` error branch returns `SizedBox.shrink()` in the screen — silent failure with no retry affordance | Medium | Fixed |
| 7 | Edge Case | `_isItemEquipped` matches `layer.url == item.imageUrl` (URL string comparison) instead of item ID — fragile if URLs change (CDN migration, cache-bust params) | Low | Skipped (item ID not in cache JSONB; functionally correct) |
| 8 | Code Quality | Admin category edit helper text references "hand=40" — stale after migration 0007 renamed to "neck=15" | Low | Fixed |
| 9 | Infra | Admin re-upload creates new storage blob without deleting the old one — orphaned files accumulate over time | Medium | Fixed |
| 10 | Feature Gap | No delete functionality in admin for bases, categories, or items (RLS allows it; UI does not expose it) | Medium | Skipped (is_active toggle sufficient for items; bases/categories rarely need deletion) |
| 11 | Code Quality | Admin `coin_price` field has no client-side minimum validation — negative values caught by DB `CHECK >= 0` but error is raw SnackBar | Low | Fixed |
| 12 | Code Quality | Admin raw Supabase errors shown on unique-constraint violations — no user-friendly duplicate-name message | Low | Fixed |

### Checklist Result (post-fix)

- Architecture Compliance: **PASS** — Clean Screen → Provider → UseCase → Repository layering; JSON in models only; `DbTables.x` and `RpcFunctions.x` used throughout; no business logic in widgets
- Code Quality: **1 remaining** — fragile string error matching (#4, codebase-wide pattern, skipped). Rarity color duplication fixed (#5), stale helper text fixed (#8), unique-constraint errors humanized (#12), coin_price validated (#11)
- Dead Code: **1 remaining** — `preview_url` column (#2, kept — no harm). `GetEquippedAvatarUseCase` pipeline deleted (#1).
- Database & Security: **PASS** — Storage upload policy restricted to `can_manage_content()` (#3 fixed); RLS on catalog tables correct; RPCs use `auth.uid()` + `SECURITY DEFINER`; coin deduction via `spend_coins_transaction`; idempotency via `user_avatar_items` composite PK
- Edge Cases & UX: **1 remaining** — URL-based equipped check (#7, skipped — item ID not in cache). Base-load error state fixed with retry (#6).
- Performance: **PASS** — No N+1; catalog cached globally via `FutureProvider`; equipped avatar derived from profile cache (zero extra queries); `autoDispose` on controller
- Cross-System Integrity: **PASS** — Coin deduction audited in `coin_logs` via `spend_coins_transaction`; no XP/badge/streak triggers (by design); `refreshProfileOnly()` after every mutation keeps leaderboard/profile avatars fresh

---

## Overview

Avatar System lets students pick a base animal (6 choices, all free) and layer purchasable accessories on top. The composed avatar is rendered as a z-indexed stack everywhere in the app (profile, leaderboard, teacher views). Each animal remembers its own outfit — switching animals saves the current look and restores the previous one. The admin manages the catalog (bases, categories, items with image upload). There is no teacher surface.

## Data Model

### Tables

**`avatar_bases`** — Base animals (6 rows)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | VARCHAR(50) UNIQUE | slug: `owl`, `fox`, `bear`, `rabbit`, `cat`, `wolf` |
| display_name | VARCHAR(100) | e.g., "Wise Owl" |
| image_url | TEXT NOT NULL | Supabase Storage URL |
| sort_order | INT | display ordering |

**`avatar_item_categories`** — Accessory slots (5 rows)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | VARCHAR(50) UNIQUE | `background`, `body`, `neck`, `face`, `head` |
| display_name | VARCHAR(100) | |
| z_index | INT | render stacking: background=0, body=10, neck=15, face=20, head=30 |
| sort_order | INT | tab ordering in UI |

**`avatar_items`** — Accessory catalog (50 seeded rows)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| category_id | UUID FK → avatar_item_categories | |
| name | VARCHAR(100) UNIQUE | slug |
| display_name | VARCHAR(150) | |
| rarity | VARCHAR(20) | CHECK: `common`, `rare`, `epic`, `legendary` (reuses `CardRarity` enum) |
| coin_price | INT | CHECK `>= 0`; auto-suggested by rarity tier |
| image_url | TEXT NOT NULL | Supabase Storage URL (transparent PNG overlay) |
| preview_url | TEXT | nullable; unused — see Finding #2 |
| is_active | BOOLEAN | default `true`; inactive items hidden from shop |

**`user_avatar_items`** — Per-user ownership + equipped state
| Column | Type | Notes |
|--------|------|-------|
| user_id | UUID FK → profiles | ON DELETE CASCADE |
| item_id | UUID FK → avatar_items | |
| is_equipped | BOOLEAN | one per category enforced by RPCs |
| purchased_at | TIMESTAMPTZ | |
| PRIMARY KEY (user_id, item_id) | | natural idempotency — can't own same item twice |

**`profiles` extension columns:**
| Column | Type | Notes |
|--------|------|-------|
| avatar_base_id | UUID FK → avatar_bases | currently selected animal |
| avatar_equipped_cache | JSONB | denormalized `{base_url, layers: [{z, url}]}` — rebuilt by `_rebuild_avatar_cache` |
| avatar_outfits | JSONB | per-animal outfit memory `{base_uuid: [item_uuid, ...]}` — managed by RPCs only |

### Key Relationships

```
profiles.avatar_base_id → avatar_bases (selected animal)
profiles.coins → buy_avatar_item → user_avatar_items (purchase)
user_avatar_items.item_id → avatar_items.category_id → avatar_item_categories (slot)
_rebuild_avatar_cache → profiles.avatar_equipped_cache (denormalized render data)
```

### RPC Functions

| Function | Purpose | Auth |
|----------|---------|------|
| `set_avatar_base(p_base_id)` | Switch animal, save old outfit, restore new animal's outfit, rebuild cache | `auth.uid()` |
| `buy_avatar_item(p_item_id)` | Deduct coins via `spend_coins_transaction`, insert ownership, auto-equip, rebuild cache | `auth.uid()` |
| `equip_avatar_item(p_item_id)` | Unequip same-category item, equip new, save outfit, rebuild cache | `auth.uid()` |
| `unequip_avatar_item(p_item_id)` | Unequip, save outfit, rebuild cache | `auth.uid()` |
| `_rebuild_avatar_cache(p_user_id)` | Internal helper: recompute JSONB cache from `avatar_base_id` + equipped items | SECURITY DEFINER |
| `_save_current_outfit(p_user_id)` | Internal helper: snapshot equipped item IDs into `avatar_outfits[base_id]` | SECURITY DEFINER |

### RLS Policies

| Table | Policy | Type |
|-------|--------|------|
| avatar_bases | All authenticated can read | SELECT |
| avatar_bases | Admins/teachers can manage | ALL (`can_manage_content()`) |
| avatar_item_categories | All authenticated can read | SELECT |
| avatar_item_categories | Admins/teachers can manage | ALL |
| avatar_items | Authenticated can read active items (`is_active = true`) | SELECT |
| avatar_items | Admins/teachers can manage | ALL |
| user_avatar_items | Users can read own items | SELECT (own rows) |
| user_avatar_items | No direct INSERT/UPDATE — all via SECURITY DEFINER RPCs | — |
| Storage `avatars` bucket | All authenticated can upload/update (overly permissive — see Finding #3) | INSERT, UPDATE |

### Indexes

| Index | On | Notes |
|-------|----|-------|
| `idx_avatar_items_category` | `avatar_items(category_id) WHERE is_active = true` | Partial index for shop queries |
| `idx_user_avatar_items_user` | `user_avatar_items(user_id)` | User ownership lookup |
| `idx_user_avatar_items_equipped` | `user_avatar_items(user_id) WHERE is_equipped = true` | Cache rebuild query |

## Surfaces

### Admin

**Entry point:** Dashboard → Avatar management card → `/avatars`

**3-tab management screen:**
1. **Hayvanlar (Bases):** 3-column grid of base animals with image, display_name, sort_order. Tap → edit screen.
2. **Kategoriler (Categories):** List with z_index, name, sort_order. Tap → edit screen.
3. **Aksesuarlar (Items):** Category-filterable grid with rarity-colored border, price, active flag. Tap → edit screen.

**Base edit** (`/avatars/bases/:id` or `/avatars/bases/new`):
- Fields: name (slug), display_name, sort_order, image upload (PNG/JPG/SVG/WebP)
- Upload path: `bases/{slug}_{timestamp}.{ext}` → Supabase Storage `avatars` bucket
- No delete button

**Category edit** (`/avatars/categories/:id` or `/avatars/categories/new`):
- Fields: name (slug), display_name, z_index, sort_order
- No image support (categories are config-only)
- No delete button

**Item edit** (`/avatars/items/:id` or `/avatars/items/new`):
- Fields: name (slug), display_name, category (dropdown), rarity (dropdown → auto-fills coin_price), coin_price (overridable), is_active toggle, image upload (PNG/JPG/WebP)
- Upload path: `items/{slug}_{timestamp}.{ext}`
- **Live composite preview:** Stack renders the accessory on a selectable base animal for visual QA
- No delete button; soft-disable via `is_active` toggle

**Rarity → auto-price mapping:** common=50, rare=150, epic=400, legendary=1000

**Limitations:**
- No delete for any entity (bases, categories, items)
- No bulk activate/deactivate
- `preview_url` field not exposed in UI
- Storage blobs not cleaned up on re-upload

### Student

**Entry point:** Profile screen → avatar edit pencil icon → `/avatar-customize`

**Avatar Customize Screen** (full-screen, no bottom nav):

1. **Header:** Coin balance display + back button
2. **Live preview:** `AvatarWidget` (160px) showing composed avatar in real-time
3. **Base animal row:** Horizontal scroll of 6 animals; selected one highlighted with border; tap to switch
4. **Accessory tabs:** `TabBar` with one tab per category (Background, Body, Neck, Face, Head)
5. **Item grid:** 3-column grid within each tab showing:
   - **Owned + equipped:** Green border + checkmark overlay → tap to unequip
   - **Owned + not equipped:** Default border → tap to equip
   - **Not owned:** Dimmed + coin price overlay → tap to buy (confirmation dialog)

**Purchase flow:**
1. Tap unowned item → confirmation dialog shows item name, rarity, price
2. Confirm → `buy_avatar_item` RPC → coin deduction + auto-equip
3. Success SnackBar + live preview updates instantly
4. Insufficient coins → error SnackBar

**Base switch flow:**
1. Tap different animal → `set_avatar_base` RPC
2. Server saves current animal's outfit → unequips all → sets new base → restores new animal's saved outfit
3. Preview updates; item grid reflects new equipped state

**Avatar rendering** (`AvatarWidget`):
- Reads `equippedAvatarProvider` (derived from `user.avatarEquippedCache` — no extra query)
- Stack: layers with `z < 5` → base animal at z=5 → layers with `z >= 5`
- Supports SVG (`flutter_svg`) and raster images (`cached_network_image`)
- Fallback: initials circle when no avatar configured

**Cross-feature avatar display:**
- Profile screen: `AvatarWidget` via `equippedAvatarProvider`
- Leaderboard: inline `EquippedAvatarModel.fromJson(entry.avatarEquippedCache)` → local `_Avatar` widget
- Student profile dialog: same inline parsing from `LeaderboardEntry`
- Teacher student detail: `AvatarWidget` from `user.avatarEquippedCache`
- Teacher assignment/dashboard: still uses legacy `avatarUrl` field (old single-image system)

### Teacher

N/A — no teacher-specific avatar management. Teachers see student avatars in student detail screens.

## Business Rules

1. **Base animals are free.** All 6 animals available to every student at no cost.
2. **One base at a time.** Selecting a new base replaces the old one (no multi-animal support).
3. **Per-animal outfit memory.** Switching animals saves the current outfit and restores the previously saved one for the new animal. Stored in `profiles.avatar_outfits` JSONB, managed entirely server-side.
4. **One item per category.** Equipping an item in a category (e.g., "head") auto-unequips the previously equipped item in that category. Enforced by RPCs, not client.
5. **Auto-equip on purchase.** Buying an item immediately equips it (unequipping same-category predecessor).
6. **Item prices by rarity tier.** Default prices: common=50, rare=150, epic=400, legendary=1000 coins. Admin can override per item.
7. **Rarity reuses `CardRarity` enum.** Avatar items share the 4-tier rarity system with myth cards (`common`, `rare`, `epic`, `legendary`).
8. **Coin deduction via `spend_coins_transaction`.** Reuses the coin economy's audited transaction function → creates `coin_logs` entry with source `'avatar_item'`.
9. **Natural idempotency.** `user_avatar_items` composite PK `(user_id, item_id)` prevents double-ownership. Second purchase attempt raises "Already owned".
10. **Inactive items hidden from shop.** `avatar_items.is_active = false` → excluded from shop queries (RLS + client filter). Inactive items already owned remain in user's inventory.
11. **Cache-based rendering.** All avatar display reads from `profiles.avatar_equipped_cache` JSONB — no joins needed at render time. Cache rebuilt by `_rebuild_avatar_cache` after every mutation.
12. **All seeded items start inactive.** The 50 seed items are `is_active = false` — admin must upload PNG assets and activate them.

## Cross-System Interactions

### Coin Economy → Avatar System
```
coins earned (XP=coins 1:1) → profiles.coins
  → buy_avatar_item RPC
    → spend_coins_transaction(user_id, price, 'avatar_item', item_id, description)
      → profiles.coins -= price
      → coin_logs INSERT (source: 'avatar_item', source_id: item_id)
    → user_avatar_items INSERT + auto-equip
    → _rebuild_avatar_cache
```

### Avatar System → Profile/Leaderboard
```
Any mutation (equip/unequip/setBase/buy)
  → _rebuild_avatar_cache → profiles.avatar_equipped_cache UPDATE
  → Client: refreshProfileOnly() → userControllerProvider re-fetches profile
  → equippedAvatarProvider (derived) emits new value
  → All AvatarWidget consumers re-render
```

### What Avatar System Does NOT Trigger
- No XP awards
- No badge checks
- No streak updates
- No assignment progress
- No daily quest progress

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Insufficient coins | Buy button shows price; confirmation dialog; RPC raises `'Insufficient coins'` → error SnackBar |
| Item already owned | RPC raises `'Already owned'` → error SnackBar; PK constraint prevents duplicate |
| No base selected yet | `avatar_equipped_cache` is null → `AvatarWidget` shows initials fallback |
| Switch animal with no previous outfit | New animal starts with no accessories; empty outfit `[]` saved for old animal |
| Restore outfit for sold/removed item | RPC checks `EXISTS (user_avatar_items WHERE user_id AND item_id)` before re-equipping — silently skips items no longer owned |
| Admin deactivates owned item | Item stays in user inventory; not visible in shop; equip/unequip still works |
| Admin deletes item (via Supabase Studio) | `user_avatar_items` row remains (no CASCADE on `item_id` FK) — could cause orphan errors |
| All items inactive | Shop shows "No accessories available yet." empty state |
| Base animal load failure | Silent — `SizedBox.shrink()` renders blank row (Finding #6) |
| Mutation during loading | `isMutating` guard returns null; full-screen spinner blocks additional taps |
| Two items with same image URL | `_isItemEquipped` could false-positive (Finding #7); not currently possible in catalog |

## Test Scenarios

- [ ] **Happy path:** Select a base animal → preview updates → buy an item → auto-equipped → preview shows layered avatar
- [ ] **Empty state:** Fresh user → no base selected → profile shows initials circle → open customize → see 6 bases, empty shop (if all items inactive)
- [ ] **Insufficient coins:** User with < 50 coins → tap common item → confirm → error SnackBar "Purchase failed: Insufficient coins"
- [ ] **Already owned:** Buy same item twice (via race/dev tools) → "Already owned" error
- [ ] **Category slot enforcement:** Equip head item A → equip head item B → A auto-unequipped, B equipped
- [ ] **Auto-equip on buy:** Purchase item → immediately appears equipped in preview (no manual equip step)
- [ ] **Unequip:** Tap equipped item → unequipped → preview updates → cache rebuilt
- [ ] **Animal switch - outfit save/restore:** Equip items on Owl → switch to Fox → equip different items → switch back to Owl → Owl's original outfit restored
- [ ] **Animal switch - outfit save for new animal:** First time selecting Fox (no saved outfit) → no items equipped → equip items → switch to Owl → switch back → Fox items restored
- [ ] **Coin balance sync:** After purchase → coin balance in header immediately reflects deduction
- [ ] **Leaderboard avatar:** Customize avatar → go to leaderboard → own entry shows updated composed avatar
- [ ] **Profile avatar:** Customize avatar → profile screen shows updated avatar
- [ ] **Admin create base:** Add new base animal with image → appears in student base row
- [ ] **Admin create item:** Add new item to "head" category with image, activate → appears in student shop under Head tab
- [ ] **Admin deactivate item:** Toggle `is_active` off → item disappears from shop (after app restart); already-owned items unaffected
- [ ] **Rarity auto-price:** Admin selects "epic" rarity → coin_price auto-fills 400 → admin can override to custom value

## Key Files

### App (Student)
| Layer | File |
|-------|------|
| Entities | `lib/domain/entities/avatar.dart` |
| Repository interface | `lib/domain/repositories/avatar_repository.dart` |
| UseCases | `lib/domain/usecases/avatar/` (8 files: get_avatar_bases, get_avatar_items, get_user_avatar_items, set_avatar_base, buy_avatar_item, equip_avatar_item, unequip_avatar_item, get_equipped_avatar) |
| Models | `lib/data/models/avatar/` (avatar_base_model, avatar_item_model, avatar_item_category_model, user_avatar_item_model, equipped_avatar_model) |
| Repository impl | `lib/data/repositories/supabase/supabase_avatar_repository.dart` |
| Providers | `lib/presentation/providers/avatar_provider.dart` |
| Screen | `lib/presentation/screens/avatar/avatar_customize_screen.dart` |
| Shared widget | `lib/presentation/widgets/common/avatar_widget.dart` |

### Admin
| Layer | File |
|-------|------|
| Providers | `owlio_admin/lib/features/avatars/providers/avatar_admin_providers.dart` |
| Management screen | `owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart` |
| Base edit | `owlio_admin/lib/features/avatars/screens/avatar_base_edit_screen.dart` |
| Item edit | `owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart` |
| Category edit | `owlio_admin/lib/features/avatars/screens/avatar_category_edit_screen.dart` |

### Shared Package
| File | Contents |
|------|----------|
| `packages/owlio_shared/lib/src/constants/tables.dart` | `avatarBases`, `avatarItemCategories`, `avatarItems`, `userAvatarItems` |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | `setAvatarBase`, `buyAvatarItem`, `equipAvatarItem`, `unequipAvatarItem` |
| `packages/owlio_shared/lib/src/enums/card_rarity.dart` | Shared 4-tier rarity enum (used by both cards and avatar items) |

### Database
| Migration | Purpose |
|-----------|---------|
| `20260326000001_create_avatar_tables.sql` | Tables, RLS, indexes, seed bases + categories |
| `20260326000002_create_avatar_rpcs.sql` | `_rebuild_avatar_cache`, `set_avatar_base` (v1), `buy_avatar_item` (v1), `equip/unequip` (v1) |
| `20260326000003_update_leaderboard_rpcs_avatar.sql` | Leaderboard RPCs include `avatar_equipped_cache` |
| `20260326000004_create_avatars_storage_bucket.sql` | Public `avatars` bucket (2 MB limit) |
| `20260326000005_avatars_storage_upload_policy.sql` | Storage INSERT/UPDATE policies (superseded by `20260328300001`) |
| `20260326000006_avatar_admin_rls.sql` | Admin management policies using `can_manage_content()` |
| `20260326000007_fix_avatar_base_change_and_categories.sql` | Renamed `hand` → `neck` (z=15); unequip-all on base change |
| `20260326000008_seed_avatar_items.sql` | 50 items seeded (`is_active = false`) |
| `20260327000001_per_animal_outfits.sql` | `avatar_outfits` JSONB; outfit save/restore; auto-equip on buy; `_save_current_outfit` helper |
| `20260328300001_avatar_storage_policy_fix.sql` | **Current live** — restricts avatars bucket upload to `can_manage_content()` only |

## Known Issues & Tech Debt

1. ~~Storage upload policy too permissive~~ — **Fixed** in `20260328300001_avatar_storage_policy_fix.sql`.
2. ~~Dead `GetEquippedAvatarUseCase` pipeline~~ — **Fixed**: use case, provider, and repository method deleted.
3. **`preview_url` column unused** (Finding #2) — Exists in DB schema and domain model but admin can't set it and no consumer reads it. Either expose in admin or drop column.
4. ~~`_rarityColor()` duplicated 3 times~~ — **Fixed**: `CardRarity.colorHex` getter added to shared package; all 3 consumers updated.
5. ~~Storage blob orphaning on re-upload~~ — **Fixed**: admin base and item edit screens now delete old blob before uploading new one.
6. **No admin delete UI** (Finding #10) — RLS allows deletes but no button exists. Intentional soft-disable via `is_active` for items; bases and categories have no disable mechanism.
7. ~~Stale category helper text~~ — **Fixed**: updated to "neck=15".
8. **Legacy `avatarUrl` in teacher views** — Teacher assignment detail, dashboard reports still use old single-image `avatarUrl` field, not the composed `AvatarWidget` system.
