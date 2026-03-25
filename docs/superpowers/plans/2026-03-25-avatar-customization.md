# Avatar Customization System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a layered avatar customization system where students select a base animal and equip coin-purchased accessories, visible on profile and leaderboard.

**Architecture:** Clean Architecture layers (domain → data → presentation) with Supabase backend. Denormalized JSONB cache on `profiles` for leaderboard reads. Admin panel CRUD for managing catalog. Reusable `AvatarWidget` renders composited layers via `Stack`.

**Tech Stack:** Flutter/Riverpod, Supabase (PostgreSQL + Storage), owlio_shared package

**Spec:** `docs/superpowers/specs/2026-03-25-avatar-customization-design.md`

---

## File Map

### New Files

| Layer | File | Purpose |
|-------|------|---------|
| **Migration** | `supabase/migrations/20260326000001_create_avatar_tables.sql` | Tables + columns + RLS + seed |
| **Migration** | `supabase/migrations/20260326000002_create_avatar_rpcs.sql` | RPC functions |
| **Migration** | `supabase/migrations/20260326000003_update_leaderboard_rpcs_avatar.sql` | Add `avatar_equipped_cache` to 8 leaderboard RPCs + safe_profiles |
| **Shared** | *(modify)* `packages/owlio_shared/lib/src/constants/tables.dart` | 4 new DbTables |
| **Shared** | *(modify)* `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | 4 new RpcFunctions |
| **Domain** | `lib/domain/entities/avatar.dart` | AvatarBase, AvatarItemCategory, AvatarItem, UserAvatarItem, EquippedAvatar, AvatarLayer, BuyAvatarItemResult |
| **Domain** | `lib/domain/repositories/avatar_repository.dart` | AvatarRepository interface |
| **Domain** | `lib/domain/usecases/avatar/get_avatar_bases_usecase.dart` | Fetch base animals |
| **Domain** | `lib/domain/usecases/avatar/set_avatar_base_usecase.dart` | Select/change animal |
| **Domain** | `lib/domain/usecases/avatar/get_avatar_items_usecase.dart` | Fetch item catalog |
| **Domain** | `lib/domain/usecases/avatar/get_user_avatar_items_usecase.dart` | Fetch owned items |
| **Domain** | `lib/domain/usecases/avatar/buy_avatar_item_usecase.dart` | Purchase item |
| **Domain** | `lib/domain/usecases/avatar/equip_avatar_item_usecase.dart` | Equip item |
| **Domain** | `lib/domain/usecases/avatar/unequip_avatar_item_usecase.dart` | Unequip item |
| **Domain** | `lib/domain/usecases/avatar/get_equipped_avatar_usecase.dart` | Get another user's avatar |
| **Data** | `lib/data/models/avatar/avatar_base_model.dart` | JSON ↔ AvatarBase |
| **Data** | `lib/data/models/avatar/avatar_item_category_model.dart` | JSON ↔ AvatarItemCategory |
| **Data** | `lib/data/models/avatar/avatar_item_model.dart` | JSON ↔ AvatarItem |
| **Data** | `lib/data/models/avatar/user_avatar_item_model.dart` | JSON ↔ UserAvatarItem |
| **Data** | `lib/data/models/avatar/equipped_avatar_model.dart` | JSONB ↔ EquippedAvatar |
| **Data** | `lib/data/repositories/supabase/supabase_avatar_repository.dart` | Supabase implementation |
| **Presentation** | `lib/presentation/providers/avatar_provider.dart` | All avatar providers + controllers |
| **Presentation** | `lib/presentation/widgets/common/avatar_widget.dart` | Reusable composited avatar renderer |
| **Presentation** | `lib/presentation/screens/avatar/avatar_customize_screen.dart` | Full-screen customization UI |
| **Admin** | `owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart` | Tabbed container |
| **Admin** | `owlio_admin/lib/features/avatars/screens/avatar_base_edit_screen.dart` | Animal CRUD |
| **Admin** | `owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart` | Accessory CRUD |
| **Admin** | `owlio_admin/lib/features/avatars/screens/avatar_category_edit_screen.dart` | Category CRUD |
| **Admin** | `owlio_admin/lib/features/avatars/providers/avatar_admin_providers.dart` | Admin data providers |

### Modified Files

| File | Change |
|------|--------|
| `lib/domain/entities/user.dart` | Add `avatarBaseId`, `avatarEquippedCache` fields |
| `lib/data/models/user/user_model.dart` | Parse new JSONB fields |
| `lib/data/models/user/leaderboard_entry_model.dart` | Parse `avatar_equipped_cache` |
| `lib/presentation/providers/repository_providers.dart` | Register `avatarRepositoryProvider` |
| `lib/presentation/providers/usecase_providers.dart` | Register 8 avatar usecase providers |
| `lib/presentation/screens/profile/profile_screen.dart` | Replace avatar display with `AvatarWidget` + edit button |
| `lib/presentation/widgets/home/leaderboard entry widgets` | Use `AvatarWidget` |
| `owlio_admin/lib/core/router.dart` | Add avatar management routes |

---

## Task 1: Database — Tables, Columns, RLS, Seed Data

**Files:**
- Create: `supabase/migrations/20260326000001_create_avatar_tables.sql`

- [ ] **Step 1: Write migration — tables + profile columns + RLS + seed**

```sql
-- =============================================
-- AVATAR CUSTOMIZATION TABLES
-- =============================================

-- 1. Avatar bases (6 animals)
CREATE TABLE avatar_bases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    image_url TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Avatar item categories (dynamic slots)
CREATE TABLE avatar_item_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    z_index INT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Avatar items (accessory catalog)
CREATE TABLE avatar_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES avatar_item_categories(id),
    name VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(150) NOT NULL,
    rarity VARCHAR(20) NOT NULL DEFAULT 'common'
        CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
    coin_price INT NOT NULL CHECK (coin_price >= 0),
    image_url TEXT NOT NULL,
    preview_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. User avatar items (ownership + equipped state)
CREATE TABLE user_avatar_items (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES avatar_items(id),
    is_equipped BOOLEAN DEFAULT false,
    purchased_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, item_id)
);

-- 5. Add avatar columns to profiles
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS avatar_base_id UUID REFERENCES avatar_bases(id),
    ADD COLUMN IF NOT EXISTS avatar_equipped_cache JSONB;

-- 6. Indexes
CREATE INDEX idx_avatar_items_category ON avatar_items(category_id) WHERE is_active = true;
CREATE INDEX idx_user_avatar_items_user ON user_avatar_items(user_id);
CREATE INDEX idx_user_avatar_items_equipped ON user_avatar_items(user_id) WHERE is_equipped = true;

-- =============================================
-- RLS POLICIES
-- =============================================

ALTER TABLE avatar_bases ENABLE ROW LEVEL SECURITY;
ALTER TABLE avatar_item_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE avatar_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_avatar_items ENABLE ROW LEVEL SECURITY;

-- Catalog tables: read-only for all authenticated
CREATE POLICY "avatar_bases_select" ON avatar_bases
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "avatar_item_categories_select" ON avatar_item_categories
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "avatar_items_select" ON avatar_items
    FOR SELECT TO authenticated USING (is_active = true);

-- User items: SELECT own only. INSERT/UPDATE via SECURITY DEFINER RPCs only.
CREATE POLICY "user_avatar_items_select_own" ON user_avatar_items
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- =============================================
-- SEED: Base animals
-- =============================================
INSERT INTO avatar_bases (name, display_name, image_url, sort_order) VALUES
    ('owl',    'Wise Owl',     'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/owl.png', 1),
    ('fox',    'Clever Fox',   'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/fox.png', 2),
    ('bear',   'Brave Bear',   'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/bear.png', 3),
    ('rabbit', 'Quick Rabbit', 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/rabbit.png', 4),
    ('cat',    'Curious Cat',  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/cat.png', 5),
    ('wolf',   'Noble Wolf',   'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/wolf.png', 6);

-- SEED: Item categories
INSERT INTO avatar_item_categories (name, display_name, z_index, sort_order) VALUES
    ('background', 'Background', 0,  1),
    ('body',       'Body',       10, 2),
    ('face',       'Face',       20, 3),
    ('head',       'Head',       30, 4),
    ('hand',       'Hand',       40, 5);
```

- [ ] **Step 2: Preview migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied, no errors.

- [ ] **Step 3: Apply migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260326000001_create_avatar_tables.sql
git commit -m "feat(db): create avatar tables, RLS, and seed data"
```

---

## Task 2: Database — RPC Functions

**Files:**
- Create: `supabase/migrations/20260326000002_create_avatar_rpcs.sql`

- [ ] **Step 1: Write migration — RPC functions**

```sql
-- =============================================
-- INTERNAL HELPER: Rebuild avatar equipped cache
-- =============================================
CREATE OR REPLACE FUNCTION _rebuild_avatar_cache(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_base_url TEXT;
    v_layers JSONB;
BEGIN
    -- Get base animal URL
    SELECT ab.image_url INTO v_base_url
    FROM profiles p
    JOIN avatar_bases ab ON ab.id = p.avatar_base_id
    WHERE p.id = p_user_id;

    -- Get equipped item layers sorted by z_index
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object('z', aic.z_index, 'url', ai.image_url)
        ORDER BY aic.z_index
    ), '[]'::jsonb) INTO v_layers
    FROM user_avatar_items uai
    JOIN avatar_items ai ON ai.id = uai.item_id
    JOIN avatar_item_categories aic ON aic.id = ai.category_id
    WHERE uai.user_id = p_user_id AND uai.is_equipped = true;

    -- Update cache
    UPDATE profiles
    SET avatar_equipped_cache = jsonb_build_object(
        'base_url', v_base_url,
        'layers', v_layers
    )
    WHERE id = p_user_id;
END;
$$;

-- =============================================
-- SET AVATAR BASE
-- =============================================
CREATE OR REPLACE FUNCTION set_avatar_base(p_base_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    -- Validate base exists
    IF NOT EXISTS (SELECT 1 FROM avatar_bases WHERE id = p_base_id) THEN
        RAISE EXCEPTION 'Avatar base not found';
    END IF;

    -- Update profile
    UPDATE profiles SET avatar_base_id = p_base_id WHERE id = v_user_id;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

-- =============================================
-- BUY AVATAR ITEM
-- =============================================
CREATE OR REPLACE FUNCTION buy_avatar_item(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_item RECORD;
    v_current_coins INT;
    v_coins_remaining INT;
BEGIN
    -- Get item details
    SELECT id, display_name, coin_price, is_active INTO v_item
    FROM avatar_items WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Avatar item not found';
    END IF;

    IF NOT v_item.is_active THEN
        RAISE EXCEPTION 'Avatar item is not available';
    END IF;

    -- Check if already owned
    IF EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Already owned';
    END IF;

    -- Check coins
    SELECT coins INTO v_current_coins FROM profiles WHERE id = v_user_id;
    IF v_current_coins < v_item.coin_price THEN
        RAISE EXCEPTION 'Insufficient coins';
    END IF;

    -- Deduct coins via existing transaction function
    PERFORM spend_coins_transaction(
        v_user_id,
        v_item.coin_price,
        'avatar_item',
        p_item_id,
        'Purchased: ' || v_item.display_name
    );

    -- Insert ownership
    INSERT INTO user_avatar_items (user_id, item_id, is_equipped)
    VALUES (v_user_id, p_item_id, false);

    -- Get remaining coins
    SELECT coins INTO v_coins_remaining FROM profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'coins_remaining', v_coins_remaining,
        'item_id', p_item_id
    );
END;
$$;

-- =============================================
-- EQUIP AVATAR ITEM
-- =============================================
CREATE OR REPLACE FUNCTION equip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_category_id UUID;
BEGIN
    -- Validate ownership
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Get category of this item
    SELECT category_id INTO v_category_id FROM avatar_items WHERE id = p_item_id;

    -- Unequip any currently equipped item in same category
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id
      AND is_equipped = true
      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_category_id);

    -- Equip the new item
    UPDATE user_avatar_items SET is_equipped = true
    WHERE user_id = v_user_id AND item_id = p_item_id;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

-- =============================================
-- UNEQUIP AVATAR ITEM
-- =============================================
CREATE OR REPLACE FUNCTION unequip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    -- Validate ownership
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Unequip
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND item_id = p_item_id;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;
```

- [ ] **Step 2: Preview and apply migration**

Run: `supabase db push --dry-run && supabase db push`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260326000002_create_avatar_rpcs.sql
git commit -m "feat(db): create avatar RPC functions"
```

---

## Task 3: Database — Leaderboard RPCs + safe_profiles Update

**Files:**
- Create: `supabase/migrations/20260326000003_update_leaderboard_rpcs_avatar.sql`

All 8 leaderboard RPCs need `avatar_equipped_cache JSONB` added to their RETURNS TABLE, and the `safe_profiles` view needs the new columns.

- [ ] **Step 1: Write migration**

This migration must `CREATE OR REPLACE` all 8 leaderboard functions, adding `avatar_equipped_cache JSONB` to each RETURNS TABLE and including `p.avatar_equipped_cache` in the SELECT. Also update `safe_profiles` view.

The 8 RPCs to update (all in `20260217000001` and `20260218000003`):
1. `get_weekly_class_leaderboard`
2. `get_weekly_school_leaderboard`
3. `get_user_weekly_class_position`
4. `get_user_weekly_school_position`
5. `get_class_leaderboard`
6. `get_school_leaderboard`
7. `get_user_class_position`
8. `get_user_school_position`

Read each RPC from the existing migration files, copy the full function body, and add `avatar_equipped_cache JSONB` to the RETURNS TABLE + `p.avatar_equipped_cache` to the SELECT.

Also update `safe_profiles`:
```sql
DROP VIEW IF EXISTS safe_profiles;
CREATE VIEW safe_profiles AS
SELECT
    id, school_id, class_id, role,
    first_name, last_name, avatar_url, username,
    avatar_base_id, avatar_equipped_cache,
    xp, level, current_streak, longest_streak,
    league_tier, last_activity_date, created_at
FROM profiles;

GRANT SELECT ON safe_profiles TO authenticated;
```

- [ ] **Step 2: Preview and apply**

Run: `supabase db push --dry-run && supabase db push`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260326000003_update_leaderboard_rpcs_avatar.sql
git commit -m "feat(db): add avatar_equipped_cache to leaderboard RPCs and safe_profiles"
```

---

## Task 4: Shared Package — DbTables + RpcFunctions

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/tables.dart`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Add DbTables constants**

In `tables.dart`, after the `dailyLogins` line (line 58), add:

```dart
  // Avatars
  static const avatarBases = 'avatar_bases';
  static const avatarItemCategories = 'avatar_item_categories';
  static const avatarItems = 'avatar_items';
  static const userAvatarItems = 'user_avatar_items';
```

- [ ] **Step 2: Add RpcFunctions constants**

In `rpc_functions.dart`, after `buyStreakFreeze` (line 31), add:

```dart
  // Avatars
  static const setAvatarBase = 'set_avatar_base';
  static const buyAvatarItem = 'buy_avatar_item';
  static const equipAvatarItem = 'equip_avatar_item';
  static const unequipAvatarItem = 'unequip_avatar_item';
```

- [ ] **Step 3: Run analyze**

Run: `cd packages/owlio_shared && dart analyze lib/`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/tables.dart packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(shared): add avatar DbTables and RpcFunctions constants"
```

---

## Task 5: Domain Layer — Entities

**Files:**
- Create: `lib/domain/entities/avatar.dart`

- [ ] **Step 1: Write entities**

```dart
import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

/// Base animal avatar (6 total, all free)
class AvatarBase extends Equatable {
  const AvatarBase({
    required this.id,
    required this.name,
    required this.displayName,
    required this.imageUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String displayName;
  final String imageUrl;
  final int sortOrder;

  @override
  List<Object?> get props => [id, name, displayName, imageUrl, sortOrder];
}

/// Dynamic accessory slot category
class AvatarItemCategory extends Equatable {
  const AvatarItemCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.zIndex,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String displayName;
  final int zIndex;
  final int sortOrder;

  @override
  List<Object?> get props => [id, name, displayName, zIndex, sortOrder];
}

/// Accessory item from the catalog
class AvatarItem extends Equatable {
  const AvatarItem({
    required this.id,
    required this.category,
    required this.name,
    required this.displayName,
    required this.rarity,
    required this.coinPrice,
    required this.imageUrl,
    this.previewUrl,
  });

  final String id;
  final AvatarItemCategory category;
  final String name;
  final String displayName;
  final CardRarity rarity;
  final int coinPrice;
  final String imageUrl;
  final String? previewUrl;

  @override
  List<Object?> get props => [id, category, name, displayName, rarity, coinPrice, imageUrl, previewUrl];
}

/// An item owned by a user
class UserAvatarItem extends Equatable {
  const UserAvatarItem({
    required this.userId,
    required this.item,
    required this.isEquipped,
    required this.purchasedAt,
  });

  final String userId;
  final AvatarItem item;
  final bool isEquipped;
  final DateTime purchasedAt;

  @override
  List<Object?> get props => [userId, item, isEquipped, purchasedAt];
}

/// A single render layer in the composed avatar
class AvatarLayer extends Equatable {
  const AvatarLayer({required this.zIndex, required this.url});

  final int zIndex;
  final String url;

  @override
  List<Object?> get props => [zIndex, url];
}

/// Composed avatar state (parsed from avatar_equipped_cache JSONB)
class EquippedAvatar extends Equatable {
  const EquippedAvatar({this.baseUrl, this.layers = const []});

  final String? baseUrl;
  final List<AvatarLayer> layers;

  bool get isEmpty => baseUrl == null && layers.isEmpty;
  bool get isNotEmpty => !isEmpty;

  @override
  List<Object?> get props => [baseUrl, layers];
}

/// Result of buying an avatar item
class BuyAvatarItemResult extends Equatable {
  const BuyAvatarItemResult({
    required this.coinsRemaining,
    required this.itemId,
  });

  final int coinsRemaining;
  final String itemId;

  @override
  List<Object?> get props => [coinsRemaining, itemId];
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/domain/entities/avatar.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/avatar.dart
git commit -m "feat(domain): add avatar entities"
```

---

## Task 6: Domain Layer — Repository Interface + UseCases

**Files:**
- Create: `lib/domain/repositories/avatar_repository.dart`
- Create: `lib/domain/usecases/avatar/get_avatar_bases_usecase.dart`
- Create: `lib/domain/usecases/avatar/set_avatar_base_usecase.dart`
- Create: `lib/domain/usecases/avatar/get_avatar_items_usecase.dart`
- Create: `lib/domain/usecases/avatar/get_user_avatar_items_usecase.dart`
- Create: `lib/domain/usecases/avatar/buy_avatar_item_usecase.dart`
- Create: `lib/domain/usecases/avatar/equip_avatar_item_usecase.dart`
- Create: `lib/domain/usecases/avatar/unequip_avatar_item_usecase.dart`
- Create: `lib/domain/usecases/avatar/get_equipped_avatar_usecase.dart`

- [ ] **Step 1: Write repository interface**

```dart
// lib/domain/repositories/avatar_repository.dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/avatar.dart';

abstract class AvatarRepository {
  Future<Either<Failure, List<AvatarBase>>> getAvatarBases();
  Future<Either<Failure, void>> setAvatarBase(String baseId);
  Future<Either<Failure, List<AvatarItem>>> getAvatarItems();
  Future<Either<Failure, List<UserAvatarItem>>> getUserAvatarItems(String userId);
  Future<Either<Failure, BuyAvatarItemResult>> buyAvatarItem(String itemId);
  Future<Either<Failure, void>> equipAvatarItem(String itemId);
  Future<Either<Failure, void>> unequipAvatarItem(String itemId);
  Future<Either<Failure, EquippedAvatar>> getEquippedAvatar(String userId);
}
```

- [ ] **Step 2: Write all 8 usecases**

Each follows the established pattern. Example for `buy_avatar_item_usecase.dart`:

```dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/avatar.dart';
import '../../repositories/avatar_repository.dart';
import '../usecase.dart';

class BuyAvatarItemParams {
  const BuyAvatarItemParams({required this.itemId});
  final String itemId;
}

class BuyAvatarItemUseCase implements UseCase<BuyAvatarItemResult, BuyAvatarItemParams> {
  const BuyAvatarItemUseCase(this._repository);
  final AvatarRepository _repository;

  @override
  Future<Either<Failure, BuyAvatarItemResult>> call(BuyAvatarItemParams params) {
    return _repository.buyAvatarItem(params.itemId);
  }
}
```

For `NoParams` usecases (GetAvatarBases, GetAvatarItems): use `UseCase<List<AvatarBase>, NoParams>`.
For single-string param usecases (SetAvatarBase, Equip, Unequip, GetEquippedAvatar): create a simple params class with the required ID field.
For GetUserAvatarItems: params class with `userId`.

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/domain/`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/domain/repositories/avatar_repository.dart lib/domain/usecases/avatar/
git commit -m "feat(domain): add avatar repository interface and 8 usecases"
```

---

## Task 7: Data Layer — Models

**Files:**
- Create: `lib/data/models/avatar/avatar_base_model.dart`
- Create: `lib/data/models/avatar/avatar_item_category_model.dart`
- Create: `lib/data/models/avatar/avatar_item_model.dart`
- Create: `lib/data/models/avatar/user_avatar_item_model.dart`
- Create: `lib/data/models/avatar/equipped_avatar_model.dart`

- [ ] **Step 1: Write all 5 models**

Follow the existing MythCardModel pattern: `fromJson()`, `toEntity()`, `fromEntity()`.

Key example — `equipped_avatar_model.dart` (parses JSONB cache):

```dart
import '../../../domain/entities/avatar.dart';

class EquippedAvatarModel {
  const EquippedAvatarModel({this.baseUrl, this.layers = const []});

  final String? baseUrl;
  final List<AvatarLayerModel> layers;

  factory EquippedAvatarModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EquippedAvatarModel();
    return EquippedAvatarModel(
      baseUrl: json['base_url'] as String?,
      layers: (json['layers'] as List<dynamic>?)
              ?.map((l) => AvatarLayerModel.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  EquippedAvatar toEntity() {
    return EquippedAvatar(
      baseUrl: baseUrl,
      layers: layers.map((l) => l.toEntity()).toList(),
    );
  }
}

class AvatarLayerModel {
  const AvatarLayerModel({required this.zIndex, required this.url});

  final int zIndex;
  final String url;

  factory AvatarLayerModel.fromJson(Map<String, dynamic> json) {
    return AvatarLayerModel(
      zIndex: json['z'] as int,
      url: json['url'] as String,
    );
  }

  AvatarLayer toEntity() => AvatarLayer(zIndex: zIndex, url: url);
}
```

For `avatar_item_model.dart`, use Supabase nested select for category:
```dart
factory AvatarItemModel.fromJson(Map<String, dynamic> json) {
  return AvatarItemModel(
    id: json['id'] as String,
    category: AvatarItemCategoryModel.fromJson(
      json['avatar_item_categories'] as Map<String, dynamic>,
    ),
    name: json['name'] as String,
    displayName: json['display_name'] as String,
    rarity: CardRarity.fromDbValue(json['rarity'] as String),
    coinPrice: json['coin_price'] as int,
    imageUrl: json['image_url'] as String,
    previewUrl: json['preview_url'] as String?,
  );
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/data/models/avatar/`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/avatar/
git commit -m "feat(data): add avatar models"
```

---

## Task 8: Data Layer — Repository Implementation

**Files:**
- Create: `lib/data/repositories/supabase/supabase_avatar_repository.dart`

- [ ] **Step 1: Write Supabase repository**

```dart
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/avatar.dart';
import '../../../domain/repositories/avatar_repository.dart';
import '../../models/avatar/avatar_base_model.dart';
import '../../models/avatar/avatar_item_model.dart';
import '../../models/avatar/equipped_avatar_model.dart';
import '../../models/avatar/user_avatar_item_model.dart';

class SupabaseAvatarRepository implements AvatarRepository {
  SupabaseAvatarRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<Either<Failure, List<AvatarBase>>> getAvatarBases() async {
    try {
      final response = await _supabase
          .from(DbTables.avatarBases)
          .select()
          .order('sort_order');
      return Right(
        (response as List).map((j) => AvatarBaseModel.fromJson(j).toEntity()).toList(),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setAvatarBase(String baseId) async {
    try {
      await _supabase.rpc(RpcFunctions.setAvatarBase, params: {'p_base_id': baseId});
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AvatarItem>>> getAvatarItems() async {
    try {
      final response = await _supabase
          .from(DbTables.avatarItems)
          .select('*, avatar_item_categories(*)')
          .eq('is_active', true)
          .order('coin_price');
      return Right(
        (response as List).map((j) => AvatarItemModel.fromJson(j).toEntity()).toList(),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<UserAvatarItem>>> getUserAvatarItems(String userId) async {
    try {
      final response = await _supabase
          .from(DbTables.userAvatarItems)
          .select('*, avatar_items(*, avatar_item_categories(*))')
          .eq('user_id', userId);
      return Right(
        (response as List).map((j) => UserAvatarItemModel.fromJson(j).toEntity()).toList(),
      );
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BuyAvatarItemResult>> buyAvatarItem(String itemId) async {
    try {
      final response = await _supabase.rpc(
        RpcFunctions.buyAvatarItem,
        params: {'p_item_id': itemId},
      );
      final json = response as Map<String, dynamic>;
      return Right(BuyAvatarItemResult(
        coinsRemaining: json['coins_remaining'] as int,
        itemId: json['item_id'] as String,
      ));
    } on PostgrestException catch (e) {
      if (e.message.contains('Insufficient coins')) {
        return const Left(InsufficientFundsFailure('Not enough coins'));
      }
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> equipAvatarItem(String itemId) async {
    try {
      await _supabase.rpc(RpcFunctions.equipAvatarItem, params: {'p_item_id': itemId});
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unequipAvatarItem(String itemId) async {
    try {
      await _supabase.rpc(RpcFunctions.unequipAvatarItem, params: {'p_item_id': itemId});
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, EquippedAvatar>> getEquippedAvatar(String userId) async {
    try {
      final response = await _supabase
          .from(DbTables.profiles)
          .select('avatar_equipped_cache')
          .eq('id', userId)
          .single();
      final model = EquippedAvatarModel.fromJson(
        response['avatar_equipped_cache'] as Map<String, dynamic>?,
      );
      return Right(model.toEntity());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/data/repositories/supabase/supabase_avatar_repository.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/data/repositories/supabase/supabase_avatar_repository.dart
git commit -m "feat(data): add Supabase avatar repository implementation"
```

---

## Task 9: User Entity/Model Integration

**Files:**
- Modify: `lib/domain/entities/user.dart`
- Modify: `lib/data/models/user/user_model.dart`

- [ ] **Step 1: Add fields to User entity**

In `user.dart`, add after `avatarUrl` (line 16):
```dart
    this.avatarBaseId,
    this.avatarEquippedCache,
```

Add fields after `avatarUrl` (line 39):
```dart
  final String? avatarBaseId;
  final Map<String, dynamic>? avatarEquippedCache;
```

Update `copyWith`, `props` to include both new fields.

- [ ] **Step 2: Add parsing to UserModel**

In `user_model.dart` `fromJson()`, add after `avatarUrl` parsing (line 44):
```dart
      avatarBaseId: json['avatar_base_id'] as String?,
      avatarEquippedCache: json['avatar_equipped_cache'] as Map<String, dynamic>?,
```

Add fields, update `toJson()`, `toEntity()`, `fromEntity()`, constructor. Do NOT add to `toUpdateJson()` — cache is managed by RPCs only.

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/domain/entities/user.dart lib/data/models/user/user_model.dart`

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/user.dart lib/data/models/user/user_model.dart
git commit -m "feat: add avatar fields to User entity and model"
```

---

## Task 10: Leaderboard Model Integration

**Files:**
- Modify: `lib/data/models/user/leaderboard_entry_model.dart`
- Modify: `lib/domain/entities/user.dart` (if LeaderboardEntry is there)

- [ ] **Step 1: Find and update LeaderboardEntry**

Add `avatarEquippedCache` field (Map<String, dynamic>?) to the entity and model. Parse from `avatar_equipped_cache` in `fromJson()`.

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/`

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/user/leaderboard_entry_model.dart lib/domain/entities/
git commit -m "feat: add avatar_equipped_cache to LeaderboardEntry"
```

---

## Task 11: Presentation — Provider Registration + Avatar Providers

**Files:**
- Modify: `lib/presentation/providers/repository_providers.dart`
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Create: `lib/presentation/providers/avatar_provider.dart`

- [ ] **Step 1: Register repository provider**

In `repository_providers.dart`, add import and provider:
```dart
import '../../data/repositories/supabase/supabase_avatar_repository.dart';
import '../../domain/repositories/avatar_repository.dart';

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  return SupabaseAvatarRepository();
});
```

- [ ] **Step 2: Register 8 usecase providers in usecase_providers.dart**

```dart
// Avatar usecases
final getAvatarBasesUseCaseProvider = Provider((ref) {
  return GetAvatarBasesUseCase(ref.watch(avatarRepositoryProvider));
});
// ... repeat for all 8
```

- [ ] **Step 3: Write avatar_provider.dart**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/avatar/equipped_avatar_model.dart';
import '../../domain/entities/avatar.dart';
import 'usecase_providers.dart';
import 'user_provider.dart';
import '../usecases/avatar/...';

// Data providers
final avatarBasesProvider = FutureProvider<List<AvatarBase>>((ref) async {
  final useCase = ref.watch(getAvatarBasesUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) { debugPrint('avatarBasesProvider: ${failure.message}'); return []; },
    (bases) => bases,
  );
});

final avatarShopProvider = FutureProvider<List<AvatarItem>>((ref) async {
  final useCase = ref.watch(getAvatarItemsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) { debugPrint('avatarShopProvider: ${failure.message}'); return []; },
    (items) => items,
  );
});

final userAvatarItemsProvider = FutureProvider<List<UserAvatarItem>>((ref) async {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user == null) return [];
  final useCase = ref.watch(getUserAvatarItemsUseCaseProvider);
  final result = await useCase(GetUserAvatarItemsParams(userId: user.id));
  return result.fold(
    (failure) { debugPrint('userAvatarItemsProvider: ${failure.message}'); return []; },
    (items) => items,
  );
});

// Derived: current user's equipped avatar (from profile cache, no extra query)
final equippedAvatarProvider = Provider<EquippedAvatar>((ref) {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user?.avatarEquippedCache == null) return const EquippedAvatar();
  return EquippedAvatarModel.fromJson(user!.avatarEquippedCache).toEntity();
});

// Derived: owned item IDs for quick lookup
final ownedAvatarItemIdsProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(userAvatarItemsProvider).valueOrNull ?? [];
  return items.map((i) => i.item.id).toSet();
});

// Derived: items grouped by category
final avatarItemsByCategoryProvider = Provider<Map<String, List<AvatarItem>>>((ref) {
  final items = ref.watch(avatarShopProvider).valueOrNull ?? [];
  final grouped = <String, List<AvatarItem>>{};
  for (final item in items) {
    grouped.putIfAbsent(item.category.name, () => []).add(item);
  }
  return grouped;
});
```

- [ ] **Step 4: Run analyze**

Run: `dart analyze lib/presentation/providers/`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/repository_providers.dart lib/presentation/providers/usecase_providers.dart lib/presentation/providers/avatar_provider.dart
git commit -m "feat(presentation): add avatar providers and registration"
```

---

## Task 12: AvatarWidget — Reusable Composited Renderer

**Files:**
- Create: `lib/presentation/widgets/common/avatar_widget.dart`

- [ ] **Step 1: Write AvatarWidget**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/avatar.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.avatar,
    this.size = 48,
    this.fallbackInitials,
    this.showBorder = true,
  });

  final EquippedAvatar avatar;
  final double size;
  final String? fallbackInitials;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fallback to initials if no avatar configured
    if (avatar.isEmpty) {
      return _buildInitials(theme);
    }

    // Build layers: base (z:5) + equipped items sorted by z_index
    final allLayers = <_RenderLayer>[];

    // Add equipped item layers below base (z < 5, e.g. background)
    for (final layer in avatar.layers.where((l) => l.zIndex < 5)) {
      allLayers.add(_RenderLayer(z: layer.zIndex, url: layer.url));
    }

    // Add base animal at z:5
    if (avatar.baseUrl != null) {
      allLayers.add(_RenderLayer(z: 5, url: avatar.baseUrl!));
    }

    // Add equipped item layers above base (z >= 5)
    for (final layer in avatar.layers.where((l) => l.zIndex >= 5)) {
      allLayers.add(_RenderLayer(z: layer.zIndex, url: layer.url));
    }

    allLayers.sort((a, b) => a.z.compareTo(b.z));

    return Container(
      width: size,
      height: size,
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: size > 60 ? 3 : 2,
              ),
            )
          : null,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: allLayers
              .map((layer) => CachedNetworkImage(
                    imageUrl: layer.url,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildInitials(ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
        border: showBorder
            ? Border.all(color: theme.colorScheme.primary, width: size > 60 ? 3 : 2)
            : null,
      ),
      child: Center(
        child: Text(
          fallbackInitials ?? '?',
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _RenderLayer {
  const _RenderLayer({required this.z, required this.url});
  final int z;
  final String url;
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/presentation/widgets/common/avatar_widget.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/avatar_widget.dart
git commit -m "feat(ui): add reusable AvatarWidget with layered rendering"
```

---

## Task 13: Avatar Customize Screen

**Files:**
- Create: `lib/presentation/screens/avatar/avatar_customize_screen.dart`

- [ ] **Step 1: Write the customize screen**

Full-screen customization with:
- Top: live preview (`AvatarWidget` with size 120)
- Middle: category tabs (Animal + item categories from DB) with item grids
- Bottom: coin balance + Save/Cancel
- Tap owned item → equip/unequip
- Tap unowned item → buy confirmation dialog
- "None" option per category to unequip

This is a `ConsumerStatefulWidget` that uses `avatarBasesProvider`, `avatarShopProvider`, `userAvatarItemsProvider`, `equippedAvatarProvider`, and the usecase providers for mutations.

After buy/equip/unequip: `ref.invalidate(userAvatarItemsProvider)` and reload user via `ref.invalidate(userControllerProvider)` to refresh the cache.

- [ ] **Step 2: Add route to GoRouter**

Find the router file and add:
```dart
GoRoute(
  path: '/avatar-customize',
  builder: (context, state) => const AvatarCustomizeScreen(),
),
```

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/presentation/screens/avatar/`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/avatar/ lib/app/router.dart
git commit -m "feat(ui): add avatar customization screen"
```

---

## Task 14: Profile Screen Integration

**Files:**
- Modify: `lib/presentation/screens/profile/profile_screen.dart`

- [ ] **Step 1: Update profile header**

Replace the current avatar display (initials circle or `Image.network`) with `AvatarWidget`:

```dart
// Import
import '../../widgets/common/avatar_widget.dart';
import '../../providers/avatar_provider.dart';

// In the profile header, replace the avatar circle with:
final equippedAvatar = ref.watch(equippedAvatarProvider);

Stack(
  children: [
    AvatarWidget(
      avatar: equippedAvatar,
      size: 100,
      fallbackInitials: user.initials,
    ),
    Positioned(
      bottom: -4,
      right: -4,
      child: GestureDetector(
        onTap: () => context.push('/avatar-customize'),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
          ),
          child: const Icon(Icons.edit, size: 14, color: Colors.white),
        ),
      ),
    ),
  ],
)
```

- [ ] **Step 2: Run analyze + test manually**

Run: `dart analyze lib/presentation/screens/profile/`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/profile/profile_screen.dart
git commit -m "feat(ui): integrate AvatarWidget in profile header with edit button"
```

---

## Task 15: Leaderboard Integration

**Files:**
- Modify: Leaderboard entry widgets (find the widget that renders avatar in leaderboard rows)

- [ ] **Step 1: Update leaderboard entries to use AvatarWidget**

Parse `avatar_equipped_cache` from leaderboard data and pass to `AvatarWidget` with `size: 36`. Fall back to initials when cache is null.

```dart
final equippedAvatar = entry.avatarEquippedCache != null
    ? EquippedAvatarModel.fromJson(entry.avatarEquippedCache).toEntity()
    : const EquippedAvatar();

AvatarWidget(
  avatar: equippedAvatar,
  size: 36,
  fallbackInitials: '${entry.firstName[0]}${entry.lastName[0]}',
)
```

- [ ] **Step 2: Update StudentProfileDialog similarly**

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/
git commit -m "feat(ui): integrate AvatarWidget in leaderboard and student dialog"
```

---

## Task 16: Supabase Storage — Create Bucket

- [ ] **Step 1: Create avatars bucket**

Via Supabase Dashboard → Storage → Create bucket:
- Name: `avatars`
- Public: Yes
- File size limit: 2MB

Or via SQL in a migration:
```sql
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
```

- [ ] **Step 2: Verify bucket is accessible**

Run: `curl -s https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/ | head -20`

---

## Task 17: Admin Panel — Avatar Management

**Files:**
- Create: `owlio_admin/lib/features/avatars/providers/avatar_admin_providers.dart`
- Create: `owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart`
- Create: `owlio_admin/lib/features/avatars/screens/avatar_base_edit_screen.dart`
- Create: `owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart`
- Create: `owlio_admin/lib/features/avatars/screens/avatar_category_edit_screen.dart`
- Modify: `owlio_admin/lib/core/router.dart`

- [ ] **Step 1: Write admin providers**

```dart
// FutureProviders for admin CRUD (direct Supabase, no Clean Architecture)
final avatarBasesAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase.from(DbTables.avatarBases).select().order('sort_order');
});

final avatarItemCategoriesAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase.from(DbTables.avatarItemCategories).select().order('sort_order');
});

final avatarItemsAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
      .from(DbTables.avatarItems)
      .select('*, avatar_item_categories(name, display_name)')
      .order('coin_price');
});

final avatarItemDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, itemId) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase
      .from(DbTables.avatarItems)
      .select('*, avatar_item_categories(*)')
      .eq('id', itemId)
      .maybeSingle();
});
```

- [ ] **Step 2: Write management screen (tabbed)**

3-tab screen: Bases, Categories, Items. Follow `CollectiblesScreen` tabbed pattern.

- [ ] **Step 3: Write avatar_base_edit_screen**

Two-column layout: form (name, display_name, sort_order, image upload) + preview. Follow `card_edit_screen.dart` pattern for image upload to `avatars/bases/` bucket.

- [ ] **Step 4: Write avatar_item_edit_screen**

Two-column: form (name, display_name, category dropdown, rarity dropdown, coin_price with auto-suggest, is_active, overlay upload, preview upload) + live preview (select base animal + show overlay). Follow card edit pattern.

- [ ] **Step 5: Write avatar_category_edit_screen**

Simple form: name, display_name, z_index, sort_order.

- [ ] **Step 6: Add routes to admin router**

```dart
GoRoute(path: '/avatars', builder: (_, __) => const AvatarManagementScreen()),
GoRoute(path: '/avatars/bases/new', builder: (_, __) => const AvatarBaseEditScreen()),
GoRoute(path: '/avatars/bases/:id', builder: (_, state) => AvatarBaseEditScreen(baseId: state.pathParameters['id'])),
GoRoute(path: '/avatars/items/new', builder: (_, __) => const AvatarItemEditScreen()),
GoRoute(path: '/avatars/items/:id', builder: (_, state) => AvatarItemEditScreen(itemId: state.pathParameters['id'])),
GoRoute(path: '/avatars/categories/new', builder: (_, __) => const AvatarCategoryEditScreen()),
GoRoute(path: '/avatars/categories/:id', builder: (_, state) => AvatarCategoryEditScreen(categoryId: state.pathParameters['id'])),
```

- [ ] **Step 7: Run analyze on admin panel**

Run: `cd owlio_admin && dart analyze lib/`

- [ ] **Step 8: Commit**

```bash
git add owlio_admin/lib/features/avatars/ owlio_admin/lib/core/router.dart
git commit -m "feat(admin): add avatar management screens"
```

---

## Task 18: Final Verification

- [ ] **Step 1: Full analyze**

Run: `dart analyze lib/` (main app)
Run: `cd owlio_admin && dart analyze lib/` (admin)
Run: `cd packages/owlio_shared && dart analyze lib/` (shared)
Expected: No issues in any project.

- [ ] **Step 2: Architecture rule check**

```bash
# No direct repository usage in screens
grep -r "ref\.\(read\|watch\).*RepositoryProvider" lib/presentation/screens/ | wc -l
```
Expected: 0

- [ ] **Step 3: Verify migration status**

Run: `supabase migration list`
Expected: All 3 new migrations show as applied.

- [ ] **Step 4: Manual smoke test**

1. Login as `active@demo.com` / `Test1234`
2. Go to Profile → tap edit avatar button
3. Select a base animal
4. Go to admin panel → Avatars → add a test item
5. Back in app → buy the item → equip it
6. Verify avatar shows on profile and leaderboard

- [ ] **Step 5: Final commit if any cleanup needed**
