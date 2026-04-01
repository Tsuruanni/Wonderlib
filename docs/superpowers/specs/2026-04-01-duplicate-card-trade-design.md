# Duplicate Card Trade System

**Date:** 2026-04-01
**Scope:** Trade duplicate cards for a higher-rarity card

---

## Overview

Players can trade duplicate cards of the same rarity for a random card of the next rarity tier. This gives duplicates a purpose, supports collection completion, and adds a strategic layer to the card system.

No coins are involved — pure card-for-card trade.

---

## Trade Rules

| Trade | Cost | Result |
|-------|------|--------|
| Common → Rare | 5 common duplicates | 1 rare card |
| Rare → Epic | 4 rare duplicates | 1 epic card |
| Epic → Legendary | 3 epic duplicates | 1 legendary card |

- Only duplicate cards can be traded (at least 1 copy of each card is always kept)
- Cards with `quantity = 1` appear in the grid but are **disabled/dimmed** — visible but not selectable ("safe" feeling)
- Cards with `quantity > 1` can contribute up to `quantity - 1` copies
- The user **manually selects** which cards to trade and how many of each
- Legendary cards cannot be traded up (no tier above)

---

## Result Card Selection

The received card is selected from the target rarity pool:

- **80% chance:** A card the user does NOT already own in that rarity (prioritizes collection completion)
- **20% chance:** Any random card in that rarity (may be a duplicate)
- If the user already owns ALL cards of the target rarity: 100% random (duplicate guaranteed)
- When all cards are owned, show a warning before trade: "You own all [rarity] cards — you'll get a duplicate"

---

## UX Flow

### Entry Point

A **"Trade Duplicates"** button in the right panel on the cards screen, below the existing widgets. Only visible when the user has at least 1 tradeable duplicate (any rarity with sufficient duplicates to meet the trade cost).

### Trade Screen

1. Opens as a **full-screen dialog or page**
2. **3 tabs** at top: `Common → Rare`, `Rare → Epic`, `Epic → Legendary`
3. Disabled tabs when insufficient duplicates for that tier
4. Each tab shows:
   - Header: "Select 5 common cards to trade for 1 rare card" (adapted per tier)
   - **Card grid** of the user's cards in that rarity:
     - `quantity > 1`: Normal appearance, tappable. Shows available count badge.
     - `quantity = 1`: Dimmed/50% opacity, not tappable. Shows "x1" badge with a lock icon.
   - **Selection counter**: "3 / 5 selected" progress indicator
   - Each tap on a card adds +1 to its contribution (up to `quantity - 1`). Tap again to cycle down or long-press to reset.
5. When required count is reached → **"Trade" button** becomes active (prominent, colored)
6. Trade button triggers RPC → card reveal animation → shows the new card
7. Return to trade screen (can trade again if more duplicates remain)

### Card Reveal

After a successful trade, show the received card with:
- A brief reveal animation (can reuse existing pack reveal pattern, simplified)
- "NEW!" badge if the card wasn't previously owned
- Rarity glow effect matching the card's tier

---

## Database

### New Table: `card_trade_logs`

```sql
CREATE TABLE card_trade_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    traded_rarity VARCHAR(20) NOT NULL,
    traded_cards JSONB NOT NULL,         -- { "card_id": quantity_given, ... }
    total_cards_traded INTEGER NOT NULL,  -- 5, 4, or 3
    received_card_id UUID NOT NULL REFERENCES myth_cards(id),
    received_rarity VARCHAR(20) NOT NULL,
    was_new_card BOOLEAN NOT NULL,
    idempotency_key UUID UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_card_trade_logs_user ON card_trade_logs(user_id);

ALTER TABLE card_trade_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own trade logs"
    ON card_trade_logs FOR SELECT
    USING (user_id = auth.uid());
```

### New RPC: `trade_duplicate_cards`

```sql
CREATE OR REPLACE FUNCTION trade_duplicate_cards(
    p_user_id UUID,
    p_card_quantities JSONB,     -- { "card_uuid": amount, ... }
    p_target_rarity VARCHAR(20),
    p_idempotency_key UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_source_rarity VARCHAR(20);
    v_required_count INTEGER;
    v_total_given INTEGER := 0;
    v_card_id UUID;
    v_amount INTEGER;
    v_current_qty INTEGER;
    v_selected_card RECORD;
    v_existing RECORD;
    v_is_new BOOLEAN;
    v_new_qty INTEGER;
    v_roll DOUBLE PRECISION;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Idempotency check: return full result from previous trade
    IF p_idempotency_key IS NOT NULL THEN
        SELECT ctl.received_card_id, ctl.was_new_card,
               mc.card_no, mc.name, mc.category, mc.category_icon,
               mc.rarity, mc.power, mc.special_skill, mc.description, mc.image_url
        INTO v_existing
        FROM card_trade_logs ctl
        JOIN myth_cards mc ON mc.id = ctl.received_card_id
        WHERE ctl.idempotency_key = p_idempotency_key;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'received_card', jsonb_build_object(
                    'id', v_existing.received_card_id,
                    'card_no', v_existing.card_no,
                    'name', v_existing.name,
                    'category', v_existing.category,
                    'category_icon', v_existing.category_icon,
                    'rarity', v_existing.rarity,
                    'power', v_existing.power,
                    'special_skill', v_existing.special_skill,
                    'description', v_existing.description,
                    'image_url', v_existing.image_url
                ),
                'is_new', v_existing.was_new_card,
                'quantity', (SELECT quantity FROM user_cards WHERE user_id = p_user_id AND card_id = v_existing.received_card_id),
                'already_processed', true
            );
        END IF;
    END IF;

    -- Determine source rarity and required count from target
    CASE p_target_rarity
        WHEN 'rare' THEN v_source_rarity := 'common'; v_required_count := 5;
        WHEN 'epic' THEN v_source_rarity := 'rare'; v_required_count := 4;
        WHEN 'legendary' THEN v_source_rarity := 'epic'; v_required_count := 3;
        ELSE RAISE EXCEPTION 'Invalid target rarity: %', p_target_rarity;
    END CASE;

    -- Validate all given cards: correct rarity, user owns them, sufficient quantity
    FOR v_card_id, v_amount IN
        SELECT (key)::UUID, (value)::INTEGER
        FROM jsonb_each_text(p_card_quantities)
    LOOP
        IF v_amount < 1 THEN
            RAISE EXCEPTION 'Invalid amount for card %', v_card_id;
        END IF;

        SELECT uc.quantity INTO v_current_qty
        FROM user_cards uc
        JOIN myth_cards mc ON mc.id = uc.card_id
        WHERE uc.user_id = p_user_id
          AND uc.card_id = v_card_id
          AND mc.rarity = v_source_rarity
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Card % not owned or wrong rarity', v_card_id;
        END IF;

        IF v_current_qty - v_amount < 1 THEN
            RAISE EXCEPTION 'Must keep at least 1 copy of card %', v_card_id;
        END IF;

        v_total_given := v_total_given + v_amount;
    END LOOP;

    IF v_total_given != v_required_count THEN
        RAISE EXCEPTION 'Expected % cards, got %', v_required_count, v_total_given;
    END IF;

    -- Deduct cards
    FOR v_card_id, v_amount IN
        SELECT (key)::UUID, (value)::INTEGER
        FROM jsonb_each_text(p_card_quantities)
    LOOP
        UPDATE user_cards
        SET quantity = quantity - v_amount, updated_at = NOW()
        WHERE user_id = p_user_id AND card_id = v_card_id;
    END LOOP;

    -- Select result card: 80% unowned, 20% any
    v_roll := random();

    IF v_roll < 0.80 THEN
        -- Try unowned card first
        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = p_target_rarity
          AND mc.is_active = true
          AND NOT EXISTS (
              SELECT 1 FROM user_cards uc
              WHERE uc.user_id = p_user_id AND uc.card_id = mc.id
          )
        ORDER BY random()
        LIMIT 1;
    END IF;

    -- Fallback: any card of target rarity (also used for the 20% path)
    IF v_selected_card IS NULL THEN
        SELECT mc.* INTO v_selected_card
        FROM myth_cards mc
        WHERE mc.rarity = p_target_rarity
          AND mc.is_active = true
        ORDER BY random()
        LIMIT 1;
    END IF;

    -- Upsert the received card
    SELECT quantity INTO v_new_qty
    FROM user_cards
    WHERE user_id = p_user_id AND card_id = v_selected_card.id;

    IF FOUND THEN
        v_is_new := FALSE;
        v_new_qty := v_new_qty + 1;
        UPDATE user_cards
        SET quantity = v_new_qty, updated_at = NOW()
        WHERE user_id = p_user_id AND card_id = v_selected_card.id;
    ELSE
        v_is_new := TRUE;
        v_new_qty := 1;
        INSERT INTO user_cards (user_id, card_id, quantity)
        VALUES (p_user_id, v_selected_card.id, 1);
    END IF;

    -- Update unique card count
    UPDATE user_card_stats
    SET total_unique_cards = (
            SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id
        ),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- Log the trade
    INSERT INTO card_trade_logs (
        user_id, traded_rarity, traded_cards, total_cards_traded,
        received_card_id, received_rarity, was_new_card, idempotency_key
    ) VALUES (
        p_user_id, v_source_rarity, p_card_quantities, v_total_given,
        v_selected_card.id, p_target_rarity, v_is_new, p_idempotency_key
    );

    -- Return result
    RETURN jsonb_build_object(
        'received_card', jsonb_build_object(
            'id', v_selected_card.id,
            'card_no', v_selected_card.card_no,
            'name', v_selected_card.name,
            'category', v_selected_card.category,
            'category_icon', v_selected_card.category_icon,
            'rarity', v_selected_card.rarity,
            'power', v_selected_card.power,
            'special_skill', v_selected_card.special_skill,
            'description', v_selected_card.description,
            'image_url', v_selected_card.image_url
        ),
        'is_new', v_is_new,
        'quantity', v_new_qty
    );
END;
$$;
```

---

## Flutter Architecture

### Domain Layer

- New entity: `TradeResult` (received card, isNew, quantity)
- New repository method: `CardRepository.tradeDuplicateCards(userId, cardQuantities, targetRarity, idempotencyKey)`
- New UseCase: `TradeDuplicateCardsUseCase`

### Data Layer

- Repository implementation calls `RpcFunctions.tradeDuplicateCards`
- Parse response into `TradeResult` (reuses `MythCard` for the received card)

### Presentation Layer

- New provider: `tradeableCardsProvider` — computed from `userCardsProvider`, grouped by rarity, filtered to `quantity > 1` for selectable and `quantity = 1` for disabled display
- New StateNotifier: `TradeSelectionController` — manages selected cards, validates count
- New screen: `card_trade_screen.dart` — tabbed trade UI
- Modified: `right_info_panel.dart` — add "Trade Duplicates" button when tradeable duplicates exist

### New Files

| File | Purpose |
|------|---------|
| `supabase/migrations/20260401100001_duplicate_card_trade.sql` | Table + RPC |
| `lib/domain/entities/trade_result.dart` | TradeResult entity |
| `lib/domain/usecases/card/trade_duplicate_cards_usecase.dart` | UseCase |
| `lib/presentation/screens/cards/card_trade_screen.dart` | Trade UI |
| `lib/presentation/providers/card_trade_provider.dart` | Trade selection state + tradeable cards |
| `lib/presentation/widgets/cards/trade_button_card.dart` | Right panel trade button widget |

### Modified Files

| File | Change |
|------|--------|
| `packages/owlio_shared/lib/src/constants/rpc_functions.dart` | Add `tradeDuplicateCards` constant |
| `lib/domain/repositories/card_repository.dart` | Add `tradeDuplicateCards` method |
| `lib/data/repositories/supabase/supabase_card_repository.dart` | Implement trade RPC call |
| `lib/presentation/providers/usecase_providers.dart` | Register trade UseCase |
| `lib/presentation/providers/card_provider.dart` | Invalidate providers after trade |
| `lib/presentation/widgets/shell/right_info_panel.dart` | Add trade button to cards route |
| `lib/app/router.dart` | Add trade screen route |

---

## Edge Cases

| Case | Behavior |
|------|----------|
| Card with quantity = 1 | Visible in grid, dimmed/disabled, not selectable |
| No duplicates in a rarity | Tab disabled, shows message |
| No duplicates at all | Trade button hidden from right panel |
| All target rarity cards owned | Trade allowed, warning shown: "You own all [rarity] cards" |
| Network failure / retry | Idempotency key prevents double-trade |
| Concurrent trades | `FOR UPDATE` lock on user_cards rows |
| User tries to trade more than quantity - 1 | RPC raises exception, client prevents this too |
