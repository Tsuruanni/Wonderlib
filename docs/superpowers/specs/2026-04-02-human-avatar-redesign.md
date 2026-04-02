# Human Avatar Redesign

## Summary

Transition the avatar system from 6 animal bases with paid accessories to 2 human bases (male/female) with free customizable parts and optional premium items. Reuses existing table structure, RPCs, cache system, and coin economy with minimal changes.

## Context

Current system: 6 free animal bases + 5 accessory categories (all paid, coin-based). New system: 2 human bases (male/female) + 9 part categories (free base parts, premium items possible later). Asset source: PSD with layered vector groups, exported as 480x480 transparent PNGs.

## Design

### Database Migration

Single migration that transforms existing avatar tables in-place.

#### 1. Add `gender` column to `avatar_items`

```sql
ALTER TABLE avatar_items
  ADD COLUMN gender VARCHAR(10) DEFAULT 'unisex'
  CHECK (gender IN ('male', 'female', 'unisex'));
```

#### 2. Clean existing data

```sql
-- All 50 seeded items are is_active = false, no real purchases exist
DELETE FROM user_avatar_items;
DELETE FROM avatar_items;
DELETE FROM avatar_item_categories;
DELETE FROM avatar_bases;

-- Reset user avatar state
UPDATE profiles SET
  avatar_base_id = NULL,
  avatar_equipped_cache = NULL,
  avatar_outfits = NULL;
```

#### 3. Insert new bases

```sql
INSERT INTO avatar_bases (id, name, display_name, image_url, sort_order) VALUES
  (gen_random_uuid(), 'male',   'Boy',  '', 1),
  (gen_random_uuid(), 'female', 'Girl', '', 2);
```

Image URLs will be set after uploading base body PNGs via admin.

#### 4. Insert new categories

```sql
INSERT INTO avatar_item_categories (id, name, display_name, z_index, sort_order) VALUES
  (gen_random_uuid(), 'face',                    'Face',                     5,  1),
  (gen_random_uuid(), 'ears',                    'Ears',                    10,  2),
  (gen_random_uuid(), 'eyes',                    'Eyes',                    15,  3),
  (gen_random_uuid(), 'brows',                   'Brows',                   20,  4),
  (gen_random_uuid(), 'noses',                   'Noses',                   25,  5),
  (gen_random_uuid(), 'mouth',                   'Mouth',                   30,  6),
  (gen_random_uuid(), 'hair',                    'Hair',                    35,  7),
  (gen_random_uuid(), 'clothes',                 'Clothes',                 40,  8),
  (gen_random_uuid(), 'additional_accessories',  'Accessories',             45,  9);
```

#### 5. Update RPCs

**`buy_avatar_item`** — Add gender guard:
```sql
-- After fetching item, before purchase:
IF v_item.gender != 'unisex' THEN
  SELECT name INTO v_base_name FROM avatar_bases WHERE id = v_user.avatar_base_id;
  IF v_item.gender != v_base_name THEN
    RAISE EXCEPTION 'Item not available for your avatar gender';
  END IF;
END IF;
```

**`equip_avatar_item`** — Same gender guard.

**`set_avatar_base`** — Add coin cost for gender change:
```sql
-- If user already has a base (not first time), charge 500 coins
IF v_old_base_id IS NOT NULL THEN
  PERFORM spend_coins_transaction(
    p_user_id, 500, 'avatar_gender_change', p_base_id::text,
    'Avatar gender change'
  );
END IF;
-- Rest of existing logic (save outfit, switch base, restore outfit, rebuild cache)
```

Note: First-time base selection (onboarding) is free because `avatar_base_id` is NULL.

**`_rebuild_avatar_cache`** — No changes needed (already reads base + equipped items by z-index).

### Domain Layer

**`avatar.dart`** — Add `gender` field to `AvatarItem` entity:
```dart
class AvatarItem extends Equatable {
  // ... existing fields ...
  final String gender; // 'male', 'female', 'unisex'
}
```

No other entity changes. Repository interface and use cases remain unchanged.

### Data Layer

**`avatar_item_model.dart`** — Parse gender from JSON:
```dart
factory AvatarItemModel.fromJson(Map<String, dynamic> json) {
  return AvatarItemModel(
    // ... existing fields ...
    gender: json['gender'] as String? ?? 'unisex',
  );
}
```

### Presentation Layer

#### Provider changes (`avatar_provider.dart`)

New gender-filtered provider:
```dart
final genderFilteredShopProvider = Provider<AsyncValue<List<AvatarItem>>>((ref) {
  final items = ref.watch(avatarShopProvider);
  final user = ref.watch(currentUserProvider);
  final bases = ref.watch(avatarBasesProvider);

  // Determine current gender from user.avatarBaseId → base.name
  // Filter: item.gender == 'unisex' || item.gender == currentGender
});
```

#### Avatar Setup Screen (NEW)

**Route:** `/avatar-setup`
**Trigger:** `avatar_base_id == null` on login/app start

Flow:
1. Full-screen welcome: "Let's create your avatar!"
2. Two large cards: Boy silhouette / Girl silhouette
3. Tap to select → navigates to customize screen with selected base
4. Customize screen has "Done" button → saves and returns to main app

This screen is shown once. After first setup, users go directly to the customize screen from profile.

#### Customize Screen changes (`avatar_customize_screen.dart`)

- **Base selection row:** 2 human silhouettes instead of 6 animals
- **Gender switch:** Tapping the other gender shows confirmation dialog: "Change gender for 500 coins? This will reset your equipped items." with coin balance display
- **Tab bar:** 9 category tabs instead of 5
- **Free item flow:** If `item.coinPrice == 0` and not owned → tap to directly equip (skip buy confirmation dialog). Internally still calls `buy_avatar_item` RPC (0 coin deduction).
- **Item grid:** Reads from `genderFilteredShopProvider` (only shows items matching current gender + unisex)

#### AvatarWidget (`avatar_widget.dart`)

No changes. Already renders base + z-indexed layers from `avatar_equipped_cache`.

### Admin Panel

#### Item Edit Screen (`avatar_item_edit_screen.dart`)

Add gender dropdown:
```dart
DropdownButtonFormField<String>(
  value: _gender,
  items: ['male', 'female', 'unisex'].map((g) => DropdownMenuItem(
    value: g,
    child: Text(g == 'male' ? 'Erkek' : g == 'female' ? 'Kadın' : 'Unisex'),
  )).toList(),
  onChanged: (v) => setState(() => _gender = v!),
  decoration: InputDecoration(labelText: 'Cinsiyet'),
)
```

#### Management Screen (`avatar_management_screen.dart`)

- Items tab: Optional gender filter chips (Tümü / Erkek / Kadın / Unisex)
- Bases tab: Shows 2 human bases instead of 6 animals
- Categories tab: Shows 9 new categories

### Asset Pipeline

Export from PSD:
- All PNGs at **480x480** with transparent background
- Same canvas size for all parts (alignment critical)
- Naming: `{gender}_{category}_{variant}.png` (e.g., `male_hair_01.png`, `female_eyes_03.png`)
- Upload via admin panel to Supabase Storage `avatars/items/` path

### Coin Economy Integration

| Action | Cost |
|--------|------|
| First-time gender selection (onboarding) | Free |
| Gender change | 500 coins |
| Base parts (coin_price = 0) | Free |
| Premium items (coin_price > 0) | Varies by rarity |

Gender change cost uses existing `spend_coins_transaction` → logged in `coin_logs` with source `'avatar_gender_change'`.

### Per-Gender Outfit Memory

Existing `avatar_outfits` JSONB on profiles already stores per-base outfit:
```json
{
  "male-base-uuid": ["item-a", "item-b"],
  "female-base-uuid": ["item-x", "item-y"]
}
```

Switching gender (after paying 500 coins):
1. Save current outfit for current base
2. Switch to new base
3. Restore previously saved outfit for new base (if any)
4. Rebuild cache

Exactly how the current animal-switch flow works. No RPC logic changes needed for this.

## Files to Modify

| Layer | File | Change |
|-------|------|--------|
| DB | `supabase/migrations/new_migration.sql` | New migration: gender column, data swap, RPC updates |
| Shared | `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `spendCoinsTransaction` if not already exposed (for gender change) |
| Entity | `lib/domain/entities/avatar.dart` | Add `gender` to `AvatarItem` |
| Model | `lib/data/models/avatar/avatar_item_model.dart` | Parse `gender` |
| Provider | `lib/presentation/providers/avatar_provider.dart` | Gender-filtered provider |
| Screen | `lib/presentation/screens/avatar/avatar_customize_screen.dart` | 2 bases, 9 tabs, free flow, gender change dialog |
| Screen | `lib/presentation/screens/avatar/avatar_setup_screen.dart` | **NEW** — onboarding setup |
| Widget | `lib/presentation/widgets/common/avatar_widget.dart` | No changes |
| Admin | `owlio_admin/lib/features/avatars/screens/avatar_item_edit_screen.dart` | Gender dropdown |
| Admin | `owlio_admin/lib/features/avatars/screens/avatar_management_screen.dart` | Gender filter chips |
| Routing | App router | Add `/avatar-setup` route, redirect logic for null `avatar_base_id` |

## Out of Scope

- Animated avatars (Rive/Lottie) — future consideration
- Runtime color changing (hair color picker etc.) — each color is a separate PNG variant
- Avatar sharing / social features
- Teacher avatar customization (teachers see student avatars only)

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| First login, no avatar | Redirect to avatar setup screen |
| Gender change with insufficient coins | Error dialog: "You need 500 coins to change gender" |
| Gender change resets equipped items | Outfit saved per-gender, restored when switching back |
| Unisex item equipped, then switch gender | Item stays equipped (unisex works for both) |
| Gender-specific item owned but wrong gender | Item stays in inventory, not visible in shop, cannot equip |
| Admin creates item without gender | Defaults to 'unisex' |
| All items in a category are other-gender | Category tab shows empty state |
