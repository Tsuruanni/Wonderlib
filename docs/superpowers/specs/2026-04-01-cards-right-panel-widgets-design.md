# Cards Right Panel Widgets

**Date:** 2026-04-01
**Scope:** 5 new widgets for the right info panel on the Card Collection screen

---

## Overview

The cards screen (`/cards`) currently shows only `_OpenPackCard` in the right panel. This design adds 5 card-specific widgets to increase engagement through collection progress visibility, social competition, and collector motivation.

## Panel Layout (Top to Bottom)

1. `_OpenPackCard` (existing)
2. **Collection Progress**
3. **Rarity Showcase**
4. **Top Collectors**
5. **Rarest Card Owner** (hidden when no exclusive cards)
6. **Duplicate Counter**

Panel width: 330px (unchanged). All widgets scroll within the existing panel `SingleChildScrollView`.

---

## Widget 1: Collection Progress

**Purpose:** Overall collection status with rarity breakdown.

**Data source:** `userCardsProvider` + `cardCatalogProvider` (no new providers needed)

**UI:**
- Large count: **32/96** with a linear progress bar
- 4 rarity rows below, each with:
  - Rarity label + color dot
  - Count: `20/48`
  - Colored progress bar (grey=common, blue=rare, purple=epic, gold=legendary)

**Computation:**
- Total unique = `userCards.length`
- Per-rarity unique = count `userCards` grouped by `card.rarity`
- Per-rarity total = count `cardCatalog` grouped by `rarity`

---

## Widget 2: Rarity Showcase

**Purpose:** Mini showcase of the user's rarest cards.

**Data source:** `userCardsProvider` sorted by rarity desc, then power desc

**UI:**
- Title: "Rarest Cards"
- 3 mini card images in a row (using `CachedNetworkImage`)
- Below each: card name (truncated) + power value
- Cards selected: highest rarity first, then highest power within same rarity
- If user has fewer than 3 cards, show only what they have

**Edge case:** No cards owned = widget hidden.

---

## Widget 3: Duplicate Counter

**Purpose:** Show duplicate card statistics.

**Data source:** `userCardsProvider` quantity fields

**UI:**
- Title: "Duplicates"
- Large number: total extra cards (sum of all `quantity - 1` where `quantity > 1`)
- "extra cards" label beneath
- Most duplicated card: mini image + name + "x5" quantity badge
- If no duplicates, show "No duplicates yet" with a subtle message

**Computation:**
- Total duplicates = `userCards.where((c) => c.quantity > 1).fold(0, (sum, c) => sum + c.quantity - 1)`
- Most duplicated = `userCards.reduce()` by quantity

---

## Widget 4: Top Collectors

**Purpose:** Class-scoped leaderboard of card collectors.

**Data source:** New RPC `get_class_top_collectors`

**UI:**
- Title: "Top Collectors"
- Top 3 rows: rank medal/number + student first name + unique card count
- If current user is NOT in top 3: separator line + "You: #7 — 32 cards" row
- If current user IS in top 3: no extra row

### New RPC: `get_class_top_collectors`

```sql
CREATE OR REPLACE FUNCTION get_class_top_collectors(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_id UUID;
  v_top3 JSONB;
  v_caller JSONB;
BEGIN
  SELECT class_id INTO v_class_id
  FROM profiles WHERE id = p_user_id;

  IF v_class_id IS NULL THEN
    RETURN jsonb_build_object('top3', '[]'::jsonb, 'caller', NULL);
  END IF;

  -- Single CTE, two reads
  WITH ranked AS (
    SELECT
      p.id AS user_id,
      p.first_name,
      COUNT(DISTINCT uc.card_id) AS unique_cards,
      ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT uc.card_id) DESC, p.first_name) AS rank
    FROM profiles p
    LEFT JOIN user_cards uc ON uc.user_id = p.id
    WHERE p.class_id = v_class_id
      AND p.role = 'student'
    GROUP BY p.id, p.first_name
  ),
  top3 AS (
    SELECT * FROM ranked WHERE rank <= 3
  ),
  caller AS (
    SELECT * FROM ranked WHERE user_id = p_user_id
  )
  SELECT
    (SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'user_id', user_id, 'first_name', first_name,
      'unique_cards', unique_cards, 'rank', rank
    )), '[]'::jsonb) FROM top3),
    (SELECT jsonb_build_object(
      'user_id', user_id, 'first_name', first_name,
      'unique_cards', unique_cards, 'rank', rank
    ) FROM caller)
  INTO v_top3, v_caller;

  RETURN jsonb_build_object('top3', v_top3, 'caller', v_caller);
END;
$$;
```

**Flutter side:**
- New provider: `classTopCollectorsProvider` (FutureProvider)
- New model: `TopCollectorEntry` (userId, firstName, uniqueCards, rank)
- Repository method: `getClassTopCollectors(userId)` calling `RpcFunctions.getClassTopCollectors`
- Register RPC name in `owlio_shared` package

---

## Widget 5: Rarest Card Owner

**Purpose:** Motivate by showing cards only the user owns in their class.

**Data source:** New RPC `get_exclusive_cards`

**UI:**
- Title: "Only You Have"
- 1-2 card mini images (highest rarity first) with card name
- "Only owner in class" label beneath each
- Widget completely hidden if user has no exclusive cards

### New RPC: `get_exclusive_cards`

```sql
CREATE OR REPLACE FUNCTION get_exclusive_cards(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_id UUID;
  v_result JSONB;
BEGIN
  SELECT class_id INTO v_class_id
  FROM profiles WHERE id = p_user_id;

  IF v_class_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  -- Cards that ONLY this user owns in the class
  WITH class_card_owners AS (
    SELECT uc.card_id, COUNT(DISTINCT uc.user_id) AS owner_count
    FROM user_cards uc
    JOIN profiles p ON p.id = uc.user_id
    WHERE p.class_id = v_class_id
      AND p.role = 'student'
    GROUP BY uc.card_id
  ),
  exclusive AS (
    SELECT mc.id, mc.name, mc.category, mc.rarity, mc.power, mc.image_url, mc.card_no
    FROM class_card_owners cco
    JOIN myth_cards mc ON mc.id = cco.card_id
    JOIN user_cards uc ON uc.card_id = cco.card_id AND uc.user_id = p_user_id
    WHERE cco.owner_count = 1
    ORDER BY
      CASE mc.rarity
        WHEN 'legendary' THEN 1
        WHEN 'epic' THEN 2
        WHEN 'rare' THEN 3
        WHEN 'common' THEN 4
      END,
      mc.power DESC
    LIMIT 2
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'category', category,
    'rarity', rarity,
    'power', power,
    'image_url', image_url,
    'card_no', card_no
  )), '[]'::jsonb) INTO v_result
  FROM exclusive;

  RETURN v_result;
END;
$$;
```

**Flutter side:**
- New provider: `exclusiveCardsProvider` (FutureProvider)
- Reuses `MythCard` entity (subset of fields)
- Repository method: `getExclusiveCards(userId)` calling `RpcFunctions.getExclusiveCards`
- Register RPC name in `owlio_shared` package

---

## File Changes Summary

### New Files
| File | Purpose |
|------|---------|
| `supabase/migrations/20260401000001_card_panel_rpcs.sql` | Both RPCs |
| `lib/presentation/widgets/cards/collection_progress_card.dart` | Widget 1 |
| `lib/presentation/widgets/cards/rarity_showcase_card.dart` | Widget 2 |
| `lib/presentation/widgets/cards/duplicate_counter_card.dart` | Widget 3 |
| `lib/presentation/widgets/cards/top_collectors_card.dart` | Widget 4 |
| `lib/presentation/widgets/cards/rarest_card_owner_card.dart` | Widget 5 |

### New Domain/Data Files
| File | Purpose |
|------|---------|
| `lib/domain/usecases/card/get_class_top_collectors_usecase.dart` | UseCase for top collectors RPC |
| `lib/domain/usecases/card/get_exclusive_cards_usecase.dart` | UseCase for exclusive cards RPC |

### Modified Files
| File | Change |
|------|--------|
| `lib/presentation/widgets/shell/right_info_panel.dart` | Add 5 widgets to cards route section |
| `lib/presentation/providers/card_provider.dart` | Add `classTopCollectorsProvider`, `exclusiveCardsProvider` |
| `lib/data/repositories/supabase/supabase_card_repository.dart` | Add 2 repository methods |
| `lib/domain/repositories/card_repository.dart` | Add 2 abstract methods |
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add 2 RPC names |
| `lib/presentation/providers/usecase_providers.dart` | Register 2 new UseCase providers |

### No Changes Needed
- Card entities — reuse existing `MythCard`, `UserCard`
- Card models — RPC responses parsed inline or with lightweight model

### Architecture Note
New RPC-backed providers follow the standard `Screen → Provider → UseCase → Repository` chain per CLAUDE.md rules. Two new UseCases needed:
- `GetClassTopCollectorsUseCase`
- `GetExclusiveCardsUseCase`

Widget 1-3 (client-side computed) use existing providers directly — no new UseCases needed since they derive from already-fetched data.

---

## Edge Cases

| Case | Behavior |
|------|----------|
| No cards owned | Collection Progress shows 0/96, Rarity Showcase hidden, Duplicate Counter shows "No duplicates yet" |
| No class assigned | Top Collectors and Rarest Card Owner hidden |
| User is only student in class | Top Collectors shows only them at #1, Rarest Card Owner shows all their cards as exclusive |
| All RPCs fail | Widgets show shimmer/skeleton, no crash |
