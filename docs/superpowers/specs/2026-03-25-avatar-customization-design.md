# Avatar Customization System — Design Spec

**Date:** 2026-03-25
**Status:** Approved
**Scope:** Database, Shared Package, Main App (Flutter), Admin Panel

---

## Overview

Layered avatar customization system where students select a base animal avatar and equip purchasable accessories. Accessories are organized by dynamic categories (slots) with rarity tiers and coin-based pricing. Admin panel provides full CRUD for managing avatar bases, item categories, and accessories with image uploads.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Rendering approach | Static PNG/SVG layers (Stack widget) | Simpler than Rive, faster to implement |
| Slot system | Dynamic categories, 1 item per category | Extensible — new categories added via DB, no code change |
| Rarity tiers | Reuse card_rarity enum (common/rare/epic/legendary) | Consistent with existing card system colors |
| Acquisition | Direct shop purchase (no gacha/packs) | K-12 audience — transparent, no frustration mechanics |
| Base avatars | All 6 free, switchable anytime | Low barrier, accessories are the monetization layer |
| Visibility | Profile + Leaderboard (not teacher panel) | Avoids complexity in teacher-facing screens |
| Asset storage | Supabase Storage (avatars bucket) | Admin can add items without app update |
| Read optimization | Denormalized JSONB cache on profiles | Prevents N+1 queries on leaderboard |

---

## 1. Database Schema

### 1.1 New Tables

#### `avatar_bases`
Static catalog of base animal avatars (initially 6).

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| name | VARCHAR(50) | NOT NULL, UNIQUE — 'owl', 'fox', 'bear', 'rabbit', 'cat', 'wolf' |
| display_name | VARCHAR(100) | NOT NULL — 'Wise Owl', 'Clever Fox', etc. |
| image_url | TEXT | NOT NULL — Supabase Storage URL |
| sort_order | INT | NOT NULL DEFAULT 0 |
| created_at | TIMESTAMPTZ | DEFAULT now() |

#### `avatar_item_categories`
Dynamic slot definitions. Each category = one equip slot on the avatar.

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| name | VARCHAR(50) | NOT NULL, UNIQUE — 'head', 'face', 'body', 'hand', 'background' |
| display_name | VARCHAR(100) | NOT NULL |
| z_index | INT | NOT NULL — render order (background=0, body=10, face=20, head=30, hand=40) |
| sort_order | INT | NOT NULL DEFAULT 0 — UI display order |
| created_at | TIMESTAMPTZ | DEFAULT now() |

#### `avatar_items`
Accessory catalog. Each item belongs to one category and has a rarity + coin price.

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PK, default gen_random_uuid() |
| category_id | UUID | FK → avatar_item_categories, NOT NULL |
| name | VARCHAR(100) | NOT NULL, UNIQUE |
| display_name | VARCHAR(150) | NOT NULL |
| rarity | card_rarity | NOT NULL — reuses existing enum (common/rare/epic/legendary) |
| coin_price | INT | NOT NULL, CHECK (coin_price >= 0) |
| image_url | TEXT | NOT NULL — overlay PNG (transparent background) |
| preview_url | TEXT | — shop preview thumbnail |
| is_active | BOOLEAN | DEFAULT true — soft delete |
| created_at | TIMESTAMPTZ | DEFAULT now() |

#### `user_avatar_items`
Ownership and equipped state. Composite PK prevents duplicate ownership.

| Column | Type | Constraints |
|--------|------|-------------|
| user_id | UUID | FK → profiles, PK part 1 |
| item_id | UUID | FK → avatar_items, PK part 2 |
| is_equipped | BOOLEAN | DEFAULT false |
| purchased_at | TIMESTAMPTZ | DEFAULT now() |

**Constraint:** At most 1 equipped item per category per user — enforced by `equip_avatar_item()` RPC (unequips previous before equipping new).

### 1.2 Profile Table Changes

Two new columns on `profiles`:

| Column | Type | Purpose |
|--------|------|---------|
| avatar_base_id | UUID, FK → avatar_bases | Currently selected animal (nullable — null means no avatar chosen yet) |
| avatar_equipped_cache | JSONB | Denormalized equipped state for fast reads |

#### `avatar_equipped_cache` JSONB Structure

```json
{
  "base_url": "https://...supabase.co/storage/v1/object/public/avatars/bases/owl.png",
  "layers": [
    {"z": 0, "url": "https://...avatars/items/sunset_bg.png"},
    {"z": 10, "url": "https://...avatars/items/red_cape.png"},
    {"z": 20, "url": "https://...avatars/items/round_glasses.png"},
    {"z": 30, "url": "https://...avatars/items/wizard_hat.png"}
  ]
}
```

Cache is rebuilt by every equip/unequip/set_avatar_base RPC. Source of truth remains `user_avatar_items` table.

### 1.3 RLS Policies

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| avatar_bases | All authenticated | — | — | — |
| avatar_item_categories | All authenticated | — | — | — |
| avatar_items | All authenticated (where is_active) | — | — | — |
| user_avatar_items | Own rows (auth.uid()) | Via RPC only | Via RPC only | — |

### 1.4 RPC Functions

#### `set_avatar_base(p_base_id UUID)`
- Validates base exists
- Updates `profiles.avatar_base_id`
- Rebuilds `avatar_equipped_cache`

#### `buy_avatar_item(p_item_id UUID) → JSONB`
- Validates item exists and is_active
- Checks user doesn't already own it
- Checks sufficient coins
- Calls `spend_coins_transaction()` (existing) for atomic coin deduction + logging
- Inserts into `user_avatar_items`
- Returns `{coins_remaining, item_id}`

#### `equip_avatar_item(p_item_id UUID)`
- Validates user owns the item
- Unequips any currently equipped item in the same category
- Sets `is_equipped = true` on target item
- Rebuilds `avatar_equipped_cache`

#### `unequip_avatar_item(p_item_id UUID)`
- Validates user owns the item
- Sets `is_equipped = false`
- Rebuilds `avatar_equipped_cache`

#### Helper: `_rebuild_avatar_cache(p_user_id UUID)` (internal)
- Reads `avatar_base_id` → gets base image_url
- Reads all equipped `user_avatar_items` joined with `avatar_items` and `avatar_item_categories`
- Builds JSONB with base_url + layers sorted by z_index
- Updates `profiles.avatar_equipped_cache`

### 1.5 Supabase Storage

**Bucket:** `avatars` (public)

```
avatars/
  bases/      → owl.png, fox.png, bear.png, rabbit.png, cat.png, wolf.png
  items/      → wizard_hat.png, golden_crown.png, round_glasses.png ...
  previews/   → wizard_hat_preview.png ...
```

### 1.6 Suggested Rarity Pricing

| Rarity | Coin Price | Color |
|--------|-----------|-------|
| Common | 50 | #AFAFAF (gray) |
| Rare | 150 | #1CB0F6 (blue) |
| Epic | 400 | #9B59B6 (purple) |
| Legendary | 1000 | #FFC800 (gold) |

These are default suggestions shown in admin panel. Admin can override per item.

---

## 2. Shared Package Changes

### 2.1 DbTables (4 new)

```dart
static const avatarBases = 'avatar_bases';
static const avatarItemCategories = 'avatar_item_categories';
static const avatarItems = 'avatar_items';
static const userAvatarItems = 'user_avatar_items';
```

### 2.2 RpcFunctions (4 new)

```dart
static const setAvatarBase = 'set_avatar_base';
static const buyAvatarItem = 'buy_avatar_item';
static const equipAvatarItem = 'equip_avatar_item';
static const unequipAvatarItem = 'unequip_avatar_item';
```

---

## 3. Flutter Architecture (Main App)

### 3.1 Domain Layer

#### Entities

**`AvatarBase`** — id, name, displayName, imageUrl, sortOrder

**`AvatarItemCategory`** — id, name, displayName, zIndex, sortOrder

**`AvatarItem`** — id, category (AvatarItemCategory), name, displayName, rarity (CardRarity), coinPrice, imageUrl, previewUrl

**`UserAvatarItem`** — userId, item (AvatarItem), isEquipped, purchasedAt

**`EquippedAvatar`** (value object) — baseUrl (String?), layers (List\<AvatarLayer\>)

**`AvatarLayer`** (value object) — zIndex (int), url (String)

#### Repository Interface — `AvatarRepository`

```
getAvatarBases() → Either<Failure, List<AvatarBase>>
setAvatarBase(String baseId) → Either<Failure, void>
getAvatarItems() → Either<Failure, List<AvatarItem>>
getUserAvatarItems() → Either<Failure, List<UserAvatarItem>>
buyAvatarItem(String itemId) → Either<Failure, BuyAvatarItemResult>
equipAvatarItem(String itemId) → Either<Failure, EquippedAvatar>
unequipAvatarItem(String itemId) → Either<Failure, EquippedAvatar>
getEquippedAvatar(String userId) → Either<Failure, EquippedAvatar>
```

#### UseCases (8)

| UseCase | Params | Returns |
|---------|--------|---------|
| GetAvatarBasesUseCase | NoParams | List\<AvatarBase\> |
| SetAvatarBaseUseCase | baseId | void |
| GetAvatarItemsUseCase | NoParams | List\<AvatarItem\> |
| GetUserAvatarItemsUseCase | NoParams | List\<UserAvatarItem\> |
| BuyAvatarItemUseCase | itemId | BuyAvatarItemResult |
| EquipAvatarItemUseCase | itemId | EquippedAvatar |
| UnequipAvatarItemUseCase | itemId | EquippedAvatar |
| GetEquippedAvatarUseCase | userId | EquippedAvatar |

### 3.2 Data Layer

#### Models (5)

- `AvatarBaseModel` — fromJson / toEntity
- `AvatarItemCategoryModel` — fromJson / toEntity
- `AvatarItemModel` — fromJson / toEntity (nested category via Supabase select join)
- `UserAvatarItemModel` — fromJson / toEntity (nested item)
- `EquippedAvatarModel` — fromJson(JSONB) / toEntity

#### Repository Implementation

`SupabaseAvatarRepository` — uses DbTables.* and RpcFunctions.* constants.

### 3.3 Presentation Layer

#### Providers

| Provider | Type | Purpose |
|----------|------|---------|
| avatarBasesProvider | FutureProvider | 6 animal catalog (cached) |
| avatarShopProvider | FutureProvider | All items grouped by category |
| userAvatarItemsProvider | FutureProvider | Owned items |
| equippedAvatarProvider | Provider | Derived from user's avatar_equipped_cache |
| avatarShopController | Notifier | buy/equip/unequip actions |
| avatarCustomizeController | Notifier | Base selection, preview state management |

#### Screens

**New:**
- `AvatarCustomizeScreen` — Full-screen customization. Top: live preview. Middle: category tabs with item grids. Bottom: coin balance + Save/Cancel.

**Updated:**
- `ProfileScreen` — Replace initials/URL avatar with `AvatarWidget` + edit button
- Leaderboard entries — `AvatarWidget` integration
- `StudentProfileDialog` — `AvatarWidget` for other students' avatars

#### Reusable Widget

```dart
AvatarWidget({
  required EquippedAvatar avatar,
  double size = 48,
  String? fallbackInitials,  // fallback when no avatar selected
  bool showBorder = true,
})
```

Implementation: `Stack` with `CachedNetworkImage` children sorted by z_index. Base animal at z:5 (between background and body layers). `ClipOval` for circular cropping.

Used everywhere avatars are displayed — single source of truth for rendering.

#### Item States in Customize Screen

| State | Visual | Tap Action |
|-------|--------|------------|
| Equipped | Highlighted border + "Equipped ✓" | Unequip |
| Owned (not equipped) | Normal + "Owned" | Equip (preview updates instantly) |
| Not owned (affordable) | Normal + price tag | Buy confirmation dialog |
| Not owned (too expensive) | Dimmed + price tag | Show "not enough coins" toast |
| None option | Dashed border + 🚫 | Unequip current slot |

---

## 4. Admin Panel

### 4.1 Feature Structure

```
owlio_admin/lib/features/avatars/
  screens/
    avatar_management_screen.dart   // Tabbed: Bases | Categories | Items
    avatar_base_edit_screen.dart    // Animal CRUD + image upload
    avatar_item_edit_screen.dart    // Accessory CRUD + overlay/preview upload + live preview
    avatar_category_edit_screen.dart // Category CRUD (name, z_index, sort_order)
  providers/
    avatar_admin_providers.dart     // FutureProviders for lists + details
```

### 4.2 Screens

**Avatar Management Screen** — 3-tab container:
1. **Bases tab** — Grid of 6 animals, click to edit, + button to add
2. **Categories tab** — Table with name, display_name, z_index, sort_order, item count
3. **Items tab** — Filterable grid by category, shows preview + rarity color + price

**Avatar Base Edit** — Two-column layout (form left, preview right):
- Fields: name, display_name, sort_order
- Image upload to `avatars/bases/` bucket

**Avatar Item Edit** — Two-column layout:
- Fields: name, display_name, category (dropdown), rarity (dropdown), coin_price (auto-suggest by rarity), is_active
- Two uploads: overlay PNG → `avatars/items/`, preview PNG → `avatars/previews/`
- Live preview: select a base animal, see the overlay composed on top

**Avatar Category Edit** — Simple form:
- Fields: name, display_name, z_index, sort_order

### 4.3 Patterns

Follows existing admin panel conventions:
- `FutureProvider` for list data, `FutureProvider.family` for detail
- `ConsumerStatefulWidget` for forms with `TextEditingController`s
- `file_picker` + `supabase.storage.from('avatars').uploadBinary()` + `getPublicUrl()`
- `ref.invalidate()` after mutations to refresh lists
- GoRouter routes: `/avatars`, `/avatars/bases/:id`, `/avatars/items/new`, `/avatars/items/:id`, `/avatars/categories/:id`

---

## 5. Migration & Rollout

### 5.1 Migration Order

1. Create `avatar_bases` table + seed 6 animals
2. Create `avatar_item_categories` table + seed initial categories (head, face, body, hand, background)
3. Create `avatar_items` table
4. Create `user_avatar_items` table
5. Add `avatar_base_id` and `avatar_equipped_cache` to profiles
6. Create RPC functions (set_avatar_base, buy_avatar_item, equip_avatar_item, unequip_avatar_item, _rebuild_avatar_cache)
7. Create RLS policies
8. Create Supabase Storage bucket `avatars` with public access

### 5.2 Backward Compatibility

- `profiles.avatar_url` remains untouched — existing code continues to work
- `avatar_base_id` and `avatar_equipped_cache` are nullable — no impact on existing users
- `AvatarWidget` falls back to initials when `EquippedAvatar` is empty
- Gradual migration: once avatar system is live, `avatar_url` becomes deprecated but doesn't need immediate removal

---

## 6. Out of Scope

- Rive animations (decided: static layers)
- Gacha/pack-based acquisition (decided: direct shop)
- Avatar visibility in teacher panel
- Gifting items between students
- Limited-time / seasonal items (can be added later via `is_active` flag)
- Achievement-locked items (all items are coin-purchasable)
