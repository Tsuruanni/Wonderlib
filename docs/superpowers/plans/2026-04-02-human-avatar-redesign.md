# Human Avatar Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transition the avatar system from 6 animal bases to 2 human bases (male/female) with 9 free customizable part categories, gender filtering, onboarding setup screen, and 500-coin gender change fee.

**Architecture:** In-place table transformation via single migration. Adds `gender` column to `avatar_items`, `is_required` column to `avatar_item_categories`. Updates all 4 RPCs. Client adds gender-filtered provider, onboarding screen, and modifies customize screen for 2 bases / 9 categories / free item flow.

**Tech Stack:** Supabase (PostgreSQL RPCs, Storage), Flutter/Riverpod, owlio_shared package

**Spec:** `docs/superpowers/specs/2026-04-02-human-avatar-redesign.md`

---

## File Structure

### Files to Create
| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260402000001_human_avatar_redesign.sql` | Schema changes, data swap, RPC rewrites |
| `lib/presentation/screens/avatar/avatar_setup_screen.dart` | Onboarding gender selection screen |

### Files to Modify
| File | Change |
|------|--------|
| `lib/domain/entities/avatar.dart` | Add `gender` to `AvatarItem`, `isRequired` to `AvatarItemCategory` |
| `lib/data/models/avatar/avatar_item_model.dart` | Parse `gender` from JSON |
| `lib/data/models/avatar/avatar_item_category_model.dart` | Parse `is_required` from JSON |
| `lib/presentation/providers/avatar_provider.dart` | Add `genderFilteredShopProvider`, `currentGenderProvider` |
| `lib/presentation/screens/avatar/avatar_customize_screen.dart` | 2 bases, 9 tabs, free flow, gender change dialog |
| `lib/app/router.dart` | Add `/avatar-setup` route + redirect for null `avatar_base_id` |
| `owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart` | Add gender dropdown + save |
| `owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart` | Add gender filter chips to items tab |
| `owlio_admin/lib/features/avatars/screens/avatar_category_edit_screen.dart` | Add is_required toggle |

### Files Unchanged
| File | Why |
|------|-----|
| `lib/presentation/widgets/common/avatar_widget.dart` | Already renders z-indexed stack from cache |
| `lib/data/repositories/supabase/supabase_avatar_repository.dart` | No API changes (same RPCs, same table queries) |
| `lib/domain/repositories/avatar_repository.dart` | Interface unchanged |
| `lib/domain/usecases/avatar/*` | All use cases unchanged |
| `lib/presentation/providers/usecase_providers.dart` | No new use cases |
| `lib/presentation/providers/repository_providers.dart` | No new repositories |
| `packages/owlio_shared/lib/src/constants/tables.dart` | Same table names |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Same RPC names |

---

## Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/20260402000001_human_avatar_redesign.sql`

- [ ] **Step 1: Create migration file**

```sql
-- =============================================
-- HUMAN AVATAR REDESIGN
-- Transforms animal avatar system to human (male/female) with
-- 9 customizable part categories, gender filtering, required
-- category enforcement, and 500-coin gender change fee.
-- =============================================

-- =============================================
-- 1. SCHEMA CHANGES
-- =============================================
ALTER TABLE avatar_items
    ADD COLUMN IF NOT EXISTS gender VARCHAR(10) DEFAULT 'unisex'
    CHECK (gender IN ('male', 'female', 'unisex'));

ALTER TABLE avatar_item_categories
    ADD COLUMN IF NOT EXISTS is_required BOOLEAN NOT NULL DEFAULT true;

-- =============================================
-- 2. CLEAN EXISTING DATA
-- All 50 seeded items are is_active = false, no real purchases exist.
-- =============================================
DELETE FROM user_avatar_items;
DELETE FROM avatar_items;
DELETE FROM avatar_item_categories;
DELETE FROM avatar_bases;

UPDATE profiles SET
    avatar_base_id = NULL,
    avatar_equipped_cache = NULL,
    avatar_outfits = '{}'::jsonb;

-- =============================================
-- 3. INSERT NEW BASES (male / female)
-- image_url left empty — admin uploads body PNGs later
-- =============================================
INSERT INTO avatar_bases (id, name, display_name, image_url, sort_order) VALUES
    (gen_random_uuid(), 'male',   'Boy',  '', 1),
    (gen_random_uuid(), 'female', 'Girl', '', 2);

-- =============================================
-- 4. INSERT NEW CATEGORIES (9 slots)
-- is_required = true for all except additional_accessories
-- =============================================
INSERT INTO avatar_item_categories (id, name, display_name, z_index, sort_order, is_required) VALUES
    (gen_random_uuid(), 'face',                   'Face',        5,  1, true),
    (gen_random_uuid(), 'ears',                   'Ears',       10,  2, true),
    (gen_random_uuid(), 'eyes',                   'Eyes',       15,  3, true),
    (gen_random_uuid(), 'brows',                  'Brows',      20,  4, true),
    (gen_random_uuid(), 'noses',                  'Noses',      25,  5, true),
    (gen_random_uuid(), 'mouth',                  'Mouth',      30,  6, true),
    (gen_random_uuid(), 'hair',                   'Hair',       35,  7, true),
    (gen_random_uuid(), 'clothes',                'Clothes',    40,  8, true),
    (gen_random_uuid(), 'additional_accessories', 'Accessories', 45, 9, false);

-- =============================================
-- 5. UPDATED RPC: set_avatar_base
-- Adds: same-base guard, 500 coin charge for gender change,
-- random equip of free items for empty required categories.
-- =============================================
CREATE OR REPLACE FUNCTION set_avatar_base(p_base_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_old_base_id UUID;
    v_equipped_item_ids UUID[];
    v_outfits JSONB;
    v_restore_ids UUID[];
    v_item_id UUID;
    v_category_id UUID;
    v_new_base_name TEXT;
    v_cat RECORD;
    v_random_item UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM avatar_bases WHERE id = p_base_id) THEN
        RAISE EXCEPTION 'Avatar base not found';
    END IF;

    -- Get current state
    SELECT avatar_base_id, COALESCE(avatar_outfits, '{}'::jsonb)
    INTO v_old_base_id, v_outfits
    FROM profiles WHERE id = v_user_id;

    -- No-op if selecting same base
    IF v_old_base_id = p_base_id THEN
        RETURN;
    END IF;

    -- Charge 500 coins for gender change (skip if first-time onboarding)
    IF v_old_base_id IS NOT NULL THEN
        PERFORM spend_coins_transaction(
            v_user_id, 500, 'avatar_gender_change', p_base_id::text,
            'Avatar gender change'
        );
    END IF;

    -- Save current outfit for old base (if any)
    IF v_old_base_id IS NOT NULL THEN
        SELECT ARRAY_AGG(item_id) INTO v_equipped_item_ids
        FROM user_avatar_items
        WHERE user_id = v_user_id AND is_equipped = true;

        IF v_equipped_item_ids IS NOT NULL THEN
            v_outfits = jsonb_set(v_outfits, ARRAY[v_old_base_id::text],
                to_jsonb(v_equipped_item_ids));
        ELSE
            v_outfits = jsonb_set(v_outfits, ARRAY[v_old_base_id::text], '[]'::jsonb);
        END IF;
    END IF;

    -- Unequip all
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true;

    -- Set new base
    UPDATE profiles
    SET avatar_base_id = p_base_id, avatar_outfits = v_outfits
    WHERE id = v_user_id;

    -- Get new base name for gender filtering
    SELECT name INTO v_new_base_name FROM avatar_bases WHERE id = p_base_id;

    -- Restore outfit for new base (if saved before)
    IF v_outfits ? p_base_id::text THEN
        SELECT ARRAY(
            SELECT (jsonb_array_elements_text(v_outfits -> p_base_id::text))::UUID
        ) INTO v_restore_ids;

        IF v_restore_ids IS NOT NULL THEN
            FOREACH v_item_id IN ARRAY v_restore_ids LOOP
                IF EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = v_item_id) THEN
                    SELECT ai.category_id INTO v_category_id
                    FROM avatar_items ai WHERE ai.id = v_item_id;

                    UPDATE user_avatar_items SET is_equipped = false
                    WHERE user_id = v_user_id AND is_equipped = true
                      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_category_id);

                    UPDATE user_avatar_items SET is_equipped = true
                    WHERE user_id = v_user_id AND item_id = v_item_id;
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Fill empty required categories with random free gender-compatible items
    FOR v_cat IN SELECT * FROM avatar_item_categories WHERE is_required = true LOOP
        IF NOT EXISTS (
            SELECT 1 FROM user_avatar_items uai
            JOIN avatar_items ai ON ai.id = uai.item_id
            WHERE uai.user_id = v_user_id AND uai.is_equipped = true
              AND ai.category_id = v_cat.id
        ) THEN
            SELECT id INTO v_random_item FROM avatar_items
            WHERE category_id = v_cat.id AND is_active = true AND coin_price = 0
              AND (gender = 'unisex' OR gender = v_new_base_name)
            ORDER BY random() LIMIT 1;

            IF v_random_item IS NOT NULL THEN
                INSERT INTO user_avatar_items (user_id, item_id, is_equipped, purchased_at)
                VALUES (v_user_id, v_random_item, true, now())
                ON CONFLICT (user_id, item_id) DO UPDATE SET is_equipped = true;
            END IF;
        END IF;
    END LOOP;

    -- Rebuild cache
    PERFORM _rebuild_avatar_cache(v_user_id);
END;
$$;

COMMENT ON FUNCTION set_avatar_base IS 'Set base (male/female), charge 500 coins for gender change, save/restore outfits, random-fill empty required categories.';

-- =============================================
-- 6. UPDATED RPC: buy_avatar_item
-- Adds: gender guard (item must match base gender or be unisex)
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
    v_base_name TEXT;
BEGIN
    SELECT id, display_name, coin_price, is_active, category_id, gender INTO v_item
    FROM avatar_items WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Avatar item not found';
    END IF;

    IF NOT v_item.is_active THEN
        RAISE EXCEPTION 'Avatar item is not available';
    END IF;

    -- Gender guard
    IF v_item.gender != 'unisex' THEN
        SELECT ab.name INTO v_base_name
        FROM profiles p JOIN avatar_bases ab ON ab.id = p.avatar_base_id
        WHERE p.id = v_user_id;

        IF v_base_name IS NULL OR v_item.gender != v_base_name THEN
            RAISE EXCEPTION 'Item not available for your avatar gender';
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Already owned';
    END IF;

    SELECT coins INTO v_current_coins FROM profiles WHERE id = v_user_id;
    IF v_current_coins < v_item.coin_price THEN
        RAISE EXCEPTION 'Insufficient coins';
    END IF;

    PERFORM spend_coins_transaction(
        v_user_id,
        v_item.coin_price,
        'avatar_item',
        p_item_id,
        'Purchased: ' || v_item.display_name
    );

    INSERT INTO user_avatar_items (user_id, item_id, is_equipped)
    VALUES (v_user_id, p_item_id, false);

    -- Auto-equip: unequip same category, equip new item
    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true
      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_item.category_id);

    UPDATE user_avatar_items SET is_equipped = true
    WHERE user_id = v_user_id AND item_id = p_item_id;

    PERFORM _rebuild_avatar_cache(v_user_id);

    SELECT coins INTO v_coins_remaining FROM profiles WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'coins_remaining', v_coins_remaining,
        'item_id', p_item_id
    );
END;
$$;

COMMENT ON FUNCTION buy_avatar_item IS 'Purchase avatar item with gender guard, auto-equip, rebuild cache.';

-- =============================================
-- 7. UPDATED RPC: equip_avatar_item
-- Adds: gender guard
-- =============================================
CREATE OR REPLACE FUNCTION equip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_category_id UUID;
    v_item_gender TEXT;
    v_base_name TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Gender guard
    SELECT category_id, gender INTO v_category_id, v_item_gender
    FROM avatar_items WHERE id = p_item_id;

    IF v_item_gender != 'unisex' THEN
        SELECT ab.name INTO v_base_name
        FROM profiles p JOIN avatar_bases ab ON ab.id = p.avatar_base_id
        WHERE p.id = v_user_id;

        IF v_base_name IS NULL OR v_item_gender != v_base_name THEN
            RAISE EXCEPTION 'Item not available for your avatar gender';
        END IF;
    END IF;

    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND is_equipped = true
      AND item_id IN (SELECT id FROM avatar_items WHERE category_id = v_category_id);

    UPDATE user_avatar_items SET is_equipped = true
    WHERE user_id = v_user_id AND item_id = p_item_id;

    PERFORM _rebuild_avatar_cache(v_user_id);
    PERFORM _save_current_outfit(v_user_id);
END;
$$;

-- =============================================
-- 8. UPDATED RPC: unequip_avatar_item
-- Adds: required-category guard
-- =============================================
CREATE OR REPLACE FUNCTION unequip_avatar_item(p_item_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_required BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_avatar_items WHERE user_id = v_user_id AND item_id = p_item_id) THEN
        RAISE EXCEPTION 'Item not owned';
    END IF;

    -- Required-category guard
    SELECT c.is_required INTO v_is_required
    FROM avatar_item_categories c
    JOIN avatar_items i ON i.category_id = c.id
    WHERE i.id = p_item_id;

    IF v_is_required THEN
        RAISE EXCEPTION 'Cannot unequip required category item';
    END IF;

    UPDATE user_avatar_items SET is_equipped = false
    WHERE user_id = v_user_id AND item_id = p_item_id;

    PERFORM _rebuild_avatar_cache(v_user_id);
    PERFORM _save_current_outfit(v_user_id);
END;
$$;
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied, no errors.

- [ ] **Step 3: Push migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 4: Verify via Supabase Studio**

Check:
- `avatar_bases` has 2 rows (male, female)
- `avatar_item_categories` has 9 rows with `is_required` column
- `avatar_items` has `gender` column
- `user_avatar_items` is empty
- All profiles have `avatar_base_id = NULL`

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260402000001_human_avatar_redesign.sql
git commit -m "feat(db): human avatar redesign migration

Transform animal avatar system to human (male/female). 2 bases,
9 categories, gender column, is_required column, updated RPCs
with gender guard, required-category guard, and random equip."
```

---

## Task 2: Domain Layer — Entity Changes

**Files:**
- Modify: `lib/domain/entities/avatar.dart`

- [ ] **Step 1: Add `gender` field to `AvatarItem` entity**

In `lib/domain/entities/avatar.dart`, update the `AvatarItem` class:

```dart
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
    this.gender = 'unisex',
  });

  final String id;
  final AvatarItemCategory category;
  final String name;
  final String displayName;
  final CardRarity rarity;
  final int coinPrice;
  final String imageUrl;
  final String? previewUrl;
  final String gender;

  @override
  List<Object?> get props => [id, category, name, displayName, rarity, coinPrice, imageUrl, previewUrl, gender];
}
```

- [ ] **Step 2: Add `isRequired` field to `AvatarItemCategory` entity**

In the same file, update `AvatarItemCategory`:

```dart
class AvatarItemCategory extends Equatable {
  const AvatarItemCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.zIndex,
    this.sortOrder = 0,
    this.isRequired = true,
  });

  final String id;
  final String name;
  final String displayName;
  final int zIndex;
  final int sortOrder;
  final bool isRequired;

  @override
  List<Object?> get props => [id, name, displayName, zIndex, sortOrder, isRequired];
}
```

- [ ] **Step 3: Verify compilation**

Run: `dart analyze lib/domain/entities/avatar.dart`
Expected: No errors (models will temporarily have missing params — that's fine, we fix them in Task 3).

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/avatar.dart
git commit -m "feat(domain): add gender to AvatarItem, isRequired to AvatarItemCategory"
```

---

## Task 3: Data Layer — Model Changes

**Files:**
- Modify: `lib/data/models/avatar/avatar_item_model.dart`
- Modify: `lib/data/models/avatar/avatar_item_category_model.dart`

- [ ] **Step 1: Add `gender` to `AvatarItemModel`**

In `lib/data/models/avatar/avatar_item_model.dart`:

Add `gender` field to constructor and `fromJson`:

```dart
class AvatarItemModel {
  const AvatarItemModel({
    required this.id,
    required this.category,
    required this.name,
    required this.displayName,
    required this.rarity,
    required this.coinPrice,
    required this.imageUrl,
    this.previewUrl,
    this.gender = 'unisex',
  });

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
      gender: json['gender'] as String? ?? 'unisex',
    );
  }

  final String id;
  final AvatarItemCategoryModel category;
  final String name;
  final String displayName;
  final CardRarity rarity;
  final int coinPrice;
  final String imageUrl;
  final String? previewUrl;
  final String gender;

  AvatarItem toEntity() {
    return AvatarItem(
      id: id,
      category: category.toEntity(),
      name: name,
      displayName: displayName,
      rarity: rarity,
      coinPrice: coinPrice,
      imageUrl: imageUrl,
      previewUrl: previewUrl,
      gender: gender,
    );
  }
}
```

- [ ] **Step 2: Add `isRequired` to `AvatarItemCategoryModel`**

In `lib/data/models/avatar/avatar_item_category_model.dart`:

```dart
class AvatarItemCategoryModel {
  const AvatarItemCategoryModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.zIndex,
    this.sortOrder = 0,
    this.isRequired = true,
  });

  factory AvatarItemCategoryModel.fromJson(Map<String, dynamic> json) {
    return AvatarItemCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      zIndex: json['z_index'] as int,
      sortOrder: json['sort_order'] as int? ?? 0,
      isRequired: json['is_required'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String displayName;
  final int zIndex;
  final int sortOrder;
  final bool isRequired;

  AvatarItemCategory toEntity() {
    return AvatarItemCategory(
      id: id,
      name: name,
      displayName: displayName,
      zIndex: zIndex,
      sortOrder: sortOrder,
      isRequired: isRequired,
    );
  }
}
```

- [ ] **Step 3: Verify compilation**

Run: `dart analyze lib/data/models/avatar/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/data/models/avatar/avatar_item_model.dart lib/data/models/avatar/avatar_item_category_model.dart
git commit -m "feat(data): parse gender and isRequired from avatar JSON"
```

---

## Task 4: Presentation Layer — Provider Changes

**Files:**
- Modify: `lib/presentation/providers/avatar_provider.dart`

- [ ] **Step 1: Add `currentGenderProvider`**

After the existing `avatarBasesProvider`, add:

```dart
/// Current user's avatar gender name ('male' or 'female'), derived from base selection.
final currentGenderProvider = Provider<String?>((ref) {
  final user = ref.watch(userControllerProvider).valueOrNull;
  if (user?.avatarBaseId == null) return null;
  final bases = ref.watch(avatarBasesProvider).valueOrNull ?? [];
  final base = bases.where((b) => b.id == user!.avatarBaseId).firstOrNull;
  return base?.name;
});
```

- [ ] **Step 2: Add `genderFilteredShopProvider`**

After `avatarShopProvider`, add:

```dart
/// Shop items filtered by current gender (shows unisex + matching gender only)
final genderFilteredShopProvider = Provider<List<AvatarItem>>((ref) {
  final items = ref.watch(avatarShopProvider).valueOrNull ?? [];
  final gender = ref.watch(currentGenderProvider);
  if (gender == null) return items;
  return items.where((i) => i.gender == 'unisex' || i.gender == gender).toList();
});
```

- [ ] **Step 3: Update `avatarItemsByCategoryProvider` to use filtered items**

Replace the existing `avatarItemsByCategoryProvider`:

```dart
/// Items grouped by category, filtered by gender
final avatarItemsByCategoryProvider = Provider<Map<String, List<AvatarItem>>>((ref) {
  final items = ref.watch(genderFilteredShopProvider);
  final grouped = <String, List<AvatarItem>>{};
  for (final item in items) {
    grouped.putIfAbsent(item.category.name, () => []).add(item);
  }
  return grouped;
});
```

- [ ] **Step 4: Verify compilation**

Run: `dart analyze lib/presentation/providers/avatar_provider.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/avatar_provider.dart
git commit -m "feat(providers): add gender-filtered avatar shop provider"
```

---

## Task 5: Avatar Setup Screen (Onboarding)

**Files:**
- Create: `lib/presentation/screens/avatar/avatar_setup_screen.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Create `AvatarSetupScreen`**

Create `lib/presentation/screens/avatar/avatar_setup_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/avatar_provider.dart';

class AvatarSetupScreen extends ConsumerWidget {
  const AvatarSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bases = ref.watch(avatarBasesProvider);
    final controller = ref.watch(avatarControllerProvider);
    final isLoading = controller is AsyncLoading;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                "Let's create your avatar!",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your character',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              bases.when(
                data: (baseList) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: baseList.map((base) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GestureDetector(
                        onTap: isLoading
                            ? null
                            : () async {
                                final error = await ref
                                    .read(avatarControllerProvider.notifier)
                                    .setBase(base.id);
                                if (error != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                  return;
                                }
                                if (context.mounted) {
                                  context.go('/avatar-customize');
                                }
                              },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 140,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: theme.colorScheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: base.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.network(
                                        base.imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          base.name == 'male' ? Icons.man : Icons.woman,
                                          size: 64,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      base.name == 'male' ? Icons.man : Icons.woman,
                                      size: 64,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              base.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Failed to load. Tap to retry.'),
              ),
              if (isLoading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add route and redirect in `lib/app/router.dart`**

Add the import at the top:
```dart
import '../presentation/screens/avatar/avatar_setup_screen.dart';
```

Add the route constant:
```dart
static const avatarSetup = '/avatar-setup';
```

Add the route definition (alongside the existing `/avatar-customize` route):
```dart
GoRoute(
  path: '/avatar-setup',
  builder: (context, state) => const AvatarSetupScreen(),
),
```

Add redirect logic in the router's `redirect` callback. Find the existing redirect function and add, after login checks but before the return:

```dart
// Redirect to avatar setup if user has no avatar base selected
if (user != null && user.avatarBaseId == null) {
  const avatarSetupPath = '/avatar-setup';
  if (state.matchedLocation != avatarSetupPath &&
      state.matchedLocation != '/avatar-customize') {
    return avatarSetupPath;
  }
}
```

- [ ] **Step 3: Verify compilation**

Run: `dart analyze lib/presentation/screens/avatar/avatar_setup_screen.dart lib/app/router.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/avatar/avatar_setup_screen.dart lib/app/router.dart
git commit -m "feat(ui): add avatar setup onboarding screen with router redirect"
```

---

## Task 6: Customize Screen — Human Avatar Adaptation

**Files:**
- Modify: `lib/presentation/screens/avatar/avatar_customize_screen.dart`

This is the largest task. The screen needs these changes:
1. Base row: 2 bases instead of 6, gender change costs 500 coins
2. Tab bar: 9 category tabs
3. Item grid: gender-filtered, free items (coin_price=0) equip directly without buy dialog
4. Unequip: hidden for required categories

- [ ] **Step 1: Update `_BaseAnimalRow` to handle gender change with coin confirmation**

Replace the `_BaseAnimalRow` widget. Key changes:
- Only 2 bases shown
- Tapping the other gender shows a confirmation dialog with 500 coin fee
- If user is on the same base, no action

Find the `_BaseAnimalRow` class (around line 363) and update the `onTap` logic:

```dart
onTap: () async {
  if (base.id == currentBaseId) return; // Same base, no-op

  // Show confirmation dialog for gender change
  final user = ref.read(userControllerProvider).valueOrNull;
  final coins = user?.coins ?? 0;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Change Gender'),
      content: Text(
        'Change gender for 500 coins?\nYour current balance: $coins coins.\n\nYour equipped items will be saved and restored if you switch back.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: coins >= 500 ? () => Navigator.pop(ctx, true) : null,
          child: const Text('Change (500 coins)'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final error = await ref.read(avatarControllerProvider.notifier).setBase(base.id);
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
},
```

- [ ] **Step 2: Update `_ItemCard` tap handler for free items**

In the `_ItemCard` widget (around line 508), update the tap logic. When an unowned item has `coinPrice == 0`, skip the buy confirmation dialog:

```dart
// In the onTap handler, replace the buy flow:
if (!isOwned) {
  if (item.coinPrice == 0) {
    // Free item — buy directly (adds to ownership + auto-equips)
    final error = await ref.read(avatarControllerProvider.notifier).buyItem(item.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  } else {
    // Paid item — show confirmation dialog (existing flow)
    // ... existing buy dialog code ...
  }
  return;
}
```

- [ ] **Step 3: Hide unequip for required categories**

In the `_ItemCard` tap handler, when the item is currently equipped:

```dart
if (isEquipped) {
  // Only allow unequip for non-required categories
  if (!item.category.isRequired) {
    final error = await ref.read(avatarControllerProvider.notifier).unequipItem(item.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }
  // If required category, tap on equipped item does nothing (or show toast)
  return;
}
```

- [ ] **Step 4: Update item grid to use `genderFilteredShopProvider`**

In `_ItemGrid`, change the data source from `avatarShopProvider` to use `avatarItemsByCategoryProvider` (which now reads from `genderFilteredShopProvider`). This should already work since Task 4 updated `avatarItemsByCategoryProvider`.

- [ ] **Step 5: Verify compilation**

Run: `dart analyze lib/presentation/screens/avatar/avatar_customize_screen.dart`
Expected: No errors.

- [ ] **Step 6: Manual test**

1. Login as `fresh@demo.com` (password: `Test1234`)
2. Should redirect to `/avatar-setup`
3. Pick "Boy" → navigates to customize with random items equipped
4. See 9 category tabs
5. Tap a free item in eyes → equips directly (no buy dialog)
6. Tap equipped required-category item → nothing happens (can't unequip)
7. Go to "Accessories" tab → tap equipped item → unequips (optional category)
8. Tap the "Girl" base → 500 coin confirmation → decline → no change
9. Verify avatar renders correctly in profile

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/avatar/avatar_customize_screen.dart
git commit -m "feat(ui): adapt customize screen for human avatars

2 bases with 500-coin gender change, 9 category tabs,
free items equip directly, required categories can't unequip."
```

---

## Task 7: Admin Panel — Gender Dropdown & Filters

**Files:**
- Modify: `owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart`
- Modify: `owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart`
- Modify: `owlio_admin/lib/features/avatars/screens/avatar_category_edit_screen.dart`

- [ ] **Step 1: Add gender dropdown to item edit screen**

In `owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart`:

Add state variable (around line 35, with other state vars):
```dart
String _gender = 'unisex';
```

In `_loadData` method (around line 61), add:
```dart
_gender = data['gender'] as String? ?? 'unisex';
```

In the form body, add a `DropdownButtonFormField` after the rarity dropdown:
```dart
DropdownButtonFormField<String>(
  value: _gender,
  decoration: const InputDecoration(labelText: 'Cinsiyet'),
  items: const [
    DropdownMenuItem(value: 'male', child: Text('Erkek')),
    DropdownMenuItem(value: 'female', child: Text('Kadın')),
    DropdownMenuItem(value: 'unisex', child: Text('Unisex')),
  ],
  onChanged: (v) => setState(() => _gender = v!),
),
```

In `_save` method, add `gender` to the data map:
```dart
final data = {
  // ... existing fields ...
  'gender': _gender,
};
```

- [ ] **Step 2: Add gender filter chips to management screen items tab**

In `owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart`, in the `_ItemsTab` class:

Add state variable:
```dart
String? _selectedGender; // null = show all
```

Add filter chips row above the item list (alongside existing category filter):
```dart
Wrap(
  spacing: 8,
  children: [
    FilterChip(
      label: const Text('Tümü'),
      selected: _selectedGender == null,
      onSelected: (_) => setState(() => _selectedGender = null),
    ),
    FilterChip(
      label: const Text('Erkek'),
      selected: _selectedGender == 'male',
      onSelected: (_) => setState(() => _selectedGender = 'male'),
    ),
    FilterChip(
      label: const Text('Kadın'),
      selected: _selectedGender == 'female',
      onSelected: (_) => setState(() => _selectedGender = 'female'),
    ),
    FilterChip(
      label: const Text('Unisex'),
      selected: _selectedGender == 'unisex',
      onSelected: (_) => setState(() => _selectedGender = 'unisex'),
    ),
  ],
),
```

Add filtering logic where items are filtered (alongside existing category filter):
```dart
if (_selectedGender != null) {
  filtered = filtered.where((item) => item['gender'] == _selectedGender).toList();
}
```

- [ ] **Step 3: Add is_required toggle to category edit screen**

In `owlio_admin/lib/features/avatars/screens/avatar_category_edit_screen.dart`:

Add state variable:
```dart
bool _isRequired = true;
```

In `_loadData`:
```dart
_isRequired = data['is_required'] as bool? ?? true;
```

Add `SwitchListTile` in the form:
```dart
SwitchListTile(
  title: const Text('Zorunlu Kategori'),
  subtitle: const Text('Zorunlu kategorilerde her zaman bir item seçili olmalı'),
  value: _isRequired,
  onChanged: (v) => setState(() => _isRequired = v),
),
```

In `_save`, add to data map:
```dart
'is_required': _isRequired,
```

- [ ] **Step 4: Verify compilation**

Run: `dart analyze owlio_admin/lib/features/avatars/`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart owlio_admin/lib/features/avatars/screens/avatar_category_edit_screen.dart
git commit -m "feat(admin): add gender dropdown, gender filters, is_required toggle for avatar management"
```

---

## Task 8: Full Integration Verify

- [ ] **Step 1: Run dart analyze on entire project**

Run: `dart analyze lib/`
Expected: No errors related to avatar changes.

- [ ] **Step 2: Run admin analyze**

Run: `cd owlio_admin && dart analyze lib/`
Expected: No errors.

- [ ] **Step 3: Manual end-to-end test**

Test flow:
1. **Admin:** Go to Avatars → Categories → verify 9 categories with `is_required`
2. **Admin:** Go to Avatars → Items → create a test item with gender=Erkek, coin_price=0, upload a PNG, activate
3. **Admin:** Upload base body PNGs for male and female bases
4. **Student (fresh@demo.com):** Login → redirected to avatar setup → pick Boy → customize screen shows random items → 9 tabs
5. **Student:** Change items in each required category → avatar preview updates
6. **Student:** Try to unequip a required item → blocked
7. **Student:** Try gender change → 500 coin confirmation

- [ ] **Step 4: Commit any fixes**

If any issues found during testing, fix and commit.
