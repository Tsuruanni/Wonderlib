# Card Collection & League Badges — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Badge/Achievement system with 3 new condition types (`cards_collected`, `myth_category_completed`, `league_tier_reached`), wire card pack opening and weekly league reset as trigger events, seed 24 new badges, and make every new condition type fully editable from the admin panel.

**Architecture:** Additive schema change — add `condition_param VARCHAR(50) NULL` to `badges` to carry string parameters (category slug, tier name) alongside the existing `condition_value INTEGER`. The `check_and_award_badges` RPC is extended with 3 new OR branches. Two other RPCs (`open_card_pack`, `process_weekly_league_reset`) gain `PERFORM check_and_award_badges(...)` calls at the end, following the same pattern already used by `complete_vocabulary_session`. Admin form renders an extra dropdown for param-based conditions.

**Tech Stack:** PostgreSQL (Supabase RPC), Dart/Flutter (main app + admin panel), Riverpod

**Spec base:** `docs/specs/11-badge-achievement.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `supabase/migrations/20260414000002_extend_badge_conditions.sql` | Add `condition_param` column, extend CHECK constraint, rewrite `check_and_award_badges` RPC with 3 new branches (note: `000001` slot was already taken by `fix_class_lp_units_varchar_cast`) |
| `supabase/migrations/20260414000003_card_pack_badge_trigger.sql` | Rewrite `open_card_pack` RPC adding `PERFORM check_and_award_badges` at the end |
| `supabase/migrations/20260414000004_league_reset_badge_trigger.sql` | Rewrite `process_weekly_league_reset` RPC adding `PERFORM check_and_award_badges` inside the per-user loop |
| `supabase/migrations/20260414000005_seed_card_and_league_badges.sql` | INSERT 24 new badges (4 total-card + 16 category + 4 tier) |

### Modified Files
| File | Change |
|------|--------|
| `packages/owlio_shared/lib/src/enums/badge_condition_type.dart` | Add 3 new enum values (`cardsCollected`, `mythCategoryCompleted`, `leagueTierReached`) |
| `lib/domain/entities/badge.dart` | Add `conditionParam` (nullable String) field to `Badge` entity + `props` |
| `lib/data/models/badge/badge_model.dart` | Parse/serialize `condition_param` JSON field, pass through `fromEntity`/`toEntity` |
| `owlio_admin/lib/core/utils/badge_helpers.dart` | Add switch cases for 3 new types in both `getConditionLabel` and `getConditionHelper` |
| `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart` | Add `_conditionParam` state + `_conditionParamController`, render extra dropdown (category or tier) when condition_type requires param, include in save payload |
| `docs/specs/11-badge-achievement.md` | Add 3 new condition type rows to condition table, new trigger chains, new seeded badges list |

### Untouched but Important
- `lib/presentation/widgets/common/notification_card.dart` — `NotificationCard.badgeEarned` already handles icon+name+XP from RPC response; no change needed.
- `lib/presentation/providers/user_provider.dart` — badge check is already wired on XP/streak flows; card/league flows trigger via RPC-to-RPC `PERFORM`, so no client-side change needed.

---

## Task 1: DB Migration — Extend Badge Conditions Schema & RPC

**Files:**
- Create: `supabase/migrations/20260414000002_extend_badge_conditions.sql` (slot `000001` was taken by pre-existing `fix_class_lp_units_varchar_cast`)

- [ ] **Step 1: Create migration file**

Create `supabase/migrations/20260414000002_extend_badge_conditions.sql`:

```sql
-- =============================================
-- Extend Badge Conditions
-- 1. Add condition_param VARCHAR(50) NULL to badges (for category slug, tier name, etc.)
-- 2. Extend condition_type CHECK constraint with 3 new values
-- 3. Rewrite check_and_award_badges RPC with 3 new OR branches
-- =============================================

-- 1. Add column
ALTER TABLE badges
    ADD COLUMN IF NOT EXISTS condition_param VARCHAR(50);

COMMENT ON COLUMN badges.condition_param IS
    'Optional string parameter for condition types that need it (e.g., category slug, league tier name)';

-- 2. Extend CHECK constraint: drop old, add new
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;

ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
    CHECK (condition_type IN (
        'xp_total', 'streak_days', 'books_completed',
        'vocabulary_learned', 'perfect_scores',
        'level_completed', 'daily_login',
        -- New:
        'cards_collected', 'myth_category_completed', 'league_tier_reached'
    ));

-- 3. Rewrite RPC — return type unchanged, so CREATE OR REPLACE is safe
CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_learned INTEGER;
    v_perfect_scores INTEGER;
    v_cards_collected INTEGER;
    v_current_tier_ordinal INTEGER;
    v_awarded RECORD;
    v_tier_order CONSTANT TEXT[] :=
        ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Get user profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- Existing stats
    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;

    SELECT COUNT(*) INTO v_vocab_learned
    FROM vocabulary_progress WHERE user_id = p_user_id AND status = 'mastered';

    SELECT COUNT(*) INTO v_perfect_scores
    FROM activity_results WHERE user_id = p_user_id AND score = max_score;

    -- New stat: distinct cards collected (UNIQUE(user_id, card_id) guarantees distinctness)
    SELECT COUNT(*) INTO v_cards_collected
    FROM user_cards WHERE user_id = p_user_id;

    -- New stat: current tier ordinal (1=bronze .. 5=diamond, 0=unknown)
    v_current_tier_ordinal := COALESCE(
        array_position(v_tier_order, v_profile.league_tier),
        0
    );

    -- Set-based INSERT for all qualifying badges
    FOR v_awarded IN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT p_user_id, b.id
        FROM badges b
        WHERE b.is_active = TRUE
        AND NOT EXISTS (
            SELECT 1 FROM user_badges ub
            WHERE ub.user_id = p_user_id AND ub.badge_id = b.id
        )
        AND (
            (b.condition_type = 'xp_total' AND v_profile.xp >= b.condition_value) OR
            (b.condition_type = 'streak_days' AND v_profile.current_streak >= b.condition_value) OR
            (b.condition_type = 'books_completed' AND v_books_completed >= b.condition_value) OR
            (b.condition_type = 'vocabulary_learned' AND v_vocab_learned >= b.condition_value) OR
            (b.condition_type = 'perfect_scores' AND v_perfect_scores >= b.condition_value) OR
            (b.condition_type = 'level_completed' AND v_profile.level >= b.condition_value) OR
            -- New branches:
            (b.condition_type = 'cards_collected'
                AND v_cards_collected >= b.condition_value) OR
            (b.condition_type = 'myth_category_completed'
                AND b.condition_param IS NOT NULL
                AND (
                    SELECT COUNT(*) FROM user_cards uc
                    JOIN myth_cards mc ON mc.id = uc.card_id
                    WHERE uc.user_id = p_user_id
                      AND mc.category = b.condition_param
                ) >= b.condition_value) OR
            (b.condition_type = 'league_tier_reached'
                AND b.condition_param IS NOT NULL
                AND v_current_tier_ordinal >=
                    COALESCE(array_position(v_tier_order, b.condition_param), 0)
                AND v_current_tier_ordinal > 0)
        )
        ON CONFLICT DO NOTHING
        RETURNING user_badges.badge_id
    LOOP
        -- Award XP for each newly earned badge
        SELECT b.id, b.name, b.icon, b.xp_reward
        INTO badge_id, badge_name, badge_icon, xp_reward
        FROM badges b WHERE b.id = v_awarded.badge_id;

        IF xp_reward > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, xp_reward, 'badge', v_awarded.badge_id,
                'Earned: ' || badge_name
            );
        END IF;

        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION check_and_award_badges IS
    'Check and award badges with auth verification. Supports xp, streak, books, vocab, perfect_scores, level, cards_collected, myth_category_completed, league_tier_reached. Returns badge_id, badge_name, badge_icon, xp_reward';
```

- [ ] **Step 2: Dry-run the migration**

Run: `supabase db push --dry-run`

Expected output: shows pending migration `20260414000001_extend_badge_conditions.sql`, no errors about constraint conflict or function signature mismatch.

- [ ] **Step 3: Push the migration**

Run: `supabase db push`

Expected: `Finished supabase db push.`

- [ ] **Step 4: Smoke-test the RPC**

Run in Supabase SQL editor (logged in as any test user — their UID is in `auth.uid()`):

```sql
SELECT * FROM check_and_award_badges(auth.uid());
```

Expected: Returns 0 rows (no new badges qualify since none of the new seed badges exist yet). No errors.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260414000001_extend_badge_conditions.sql
git commit -m "feat(badges): add condition_param column and 3 new condition types"
```

---

## Task 2: DB Migration — Card Pack Badge Trigger

**Files:**
- Create: `supabase/migrations/20260414000003_card_pack_badge_trigger.sql`

**Context:** The latest `open_card_pack` body lives in `supabase/migrations/20260328200001_card_audit_fixes.sql`. We copy it verbatim and append a single `PERFORM check_and_award_badges(p_user_id);` call just before `RETURN jsonb_build_object(...)` at the end. Nothing else changes.

- [ ] **Step 1: Read the latest card pack RPC**

Run: `cat supabase/migrations/20260328200001_card_audit_fixes.sql`

Locate the `CREATE OR REPLACE FUNCTION open_card_pack(...)` block — this is the body to copy.

- [ ] **Step 2: Create migration file**

Create `supabase/migrations/20260414000003_card_pack_badge_trigger.sql` with the complete `open_card_pack` function body from `20260328200001_card_audit_fixes.sql`, then add the badge check as the last statement before RETURN.

**Structure** (paste the full existing body, then make this change):

```sql
-- =============================================
-- Card Pack Badge Trigger
-- Add PERFORM check_and_award_badges(...) at the end of open_card_pack
-- so cards_collected / myth_category_completed badges fire after pack opens.
-- =============================================

CREATE OR REPLACE FUNCTION open_card_pack(
    p_user_id UUID,
    p_pack_cost INTEGER DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- ... paste all DECLARE lines from 20260328200001_card_audit_fixes.sql ...
BEGIN
    -- Auth check from 20260328200001 (if present)
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- ... paste entire body (coin check, deduct, pity, roll 3 cards, upsert user_cards, stats, log) ...

    -- ===== NEW: Badge check =====
    -- Must run AFTER user_cards UPSERT + user_card_stats update so COUNT reflects new state.
    PERFORM check_and_award_badges(p_user_id);

    -- ===== RETURN RESULT (unchanged) =====
    RETURN jsonb_build_object(
        'cards', v_result_cards,
        'pack_glow_rarity', v_best_rarity,
        'coins_spent', p_pack_cost,
        'coins_remaining', v_new_coins,
        'pity_triggered', v_pity_triggered
    );
END;
$$;

COMMENT ON FUNCTION open_card_pack IS
    'Atomically open a card pack: deduct coins, roll 3 cards, pity system, check card-related badges, return results';
```

**CRITICAL:** Do not paraphrase or skip lines from the original body. The `check_and_award_badges` call must be the LAST statement before `RETURN`. The function signature, `DECLARE` block, and all business logic must be identical to the current version — only the `PERFORM` line is new.

- [ ] **Step 3: Dry-run**

Run: `supabase db push --dry-run`

Expected: shows pending migration, no errors.

- [ ] **Step 4: Push**

Run: `supabase db push`

Expected: `Finished supabase db push.`

- [ ] **Step 5: Smoke-test**

In Supabase SQL editor, as a test user with enough coins:

```sql
SELECT open_card_pack(auth.uid());
```

Expected: Returns pack JSONB (3 cards), no error. Check `user_badges` for test user to see if any card badges were inserted (only possible after Task 4 seeds them).

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260414000003_card_pack_badge_trigger.sql
git commit -m "feat(badges): trigger badge check after card pack open"
```

---

## Task 3: DB Migration — League Reset Badge Trigger

**Files:**
- Create: `supabase/migrations/20260414000004_league_reset_badge_trigger.sql`

**Context:** The latest `process_weekly_league_reset` body lives in `supabase/migrations/20260407000006_league_reset_idempotent_decay.sql`. We copy it verbatim and add `PERFORM check_and_award_badges(v_user.user_id);` inside the per-user loop that updates `profiles.league_tier`, immediately after the tier is updated (so the user's new tier is visible to the badge check).

- [ ] **Step 1: Read the latest league reset RPC**

Run: `cat supabase/migrations/20260407000006_league_reset_idempotent_decay.sql`

Locate the `CREATE OR REPLACE FUNCTION process_weekly_league_reset(...)` block and identify the per-user loop (`FOR v_user IN ... LOOP`) that assigns new `league_tier` values in `profiles`.

- [ ] **Step 2: Create migration file**

Create `supabase/migrations/20260414000004_league_reset_badge_trigger.sql`:

```sql
-- =============================================
-- League Reset Badge Trigger
-- Add PERFORM check_and_award_badges(v_user.user_id) inside per-user loop
-- of process_weekly_league_reset so league_tier_reached badges fire on promotion.
-- =============================================

CREATE OR REPLACE FUNCTION process_weekly_league_reset(...)
RETURNS ...  -- same as 20260407000006
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- ... paste all DECLARE lines from 20260407000006 ...
BEGIN
    -- ... paste entire pre-loop logic (grouping, tier transitions, etc.) ...

    FOR v_user IN /* same query as original */ LOOP
        -- ... paste existing per-user logic: UPDATE profiles SET league_tier = ...,
        --     INSERT INTO league_history ..., etc. ...

        -- ===== NEW: Badge check =====
        -- Runs AFTER profiles.league_tier UPDATE so the new tier is visible.
        -- Note: auth.uid() check inside check_and_award_badges will fail
        --       because this is a scheduled job (no session). Use a wrapper
        --       that bypasses auth, OR refactor check_and_award_badges to
        --       accept a "system" flag. See Step 2a below.
        PERFORM check_and_award_badges_system(v_user.user_id);
    END LOOP;

    -- ... paste remainder ...
END;
$$;
```

- [ ] **Step 2a: Add `check_and_award_badges_system` wrapper (no auth check)**

The existing `check_and_award_badges` enforces `p_user_id != auth.uid()`. Scheduled jobs have no `auth.uid()`, so we need a system-invoked wrapper. Add this to the same migration file (before the `process_weekly_league_reset` rewrite):

```sql
-- System-invoked variant: same logic as check_and_award_badges but skips auth.uid() check.
-- Only callable by other SECURITY DEFINER functions (not exposed to PostgREST).
CREATE OR REPLACE FUNCTION check_and_award_badges_system(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_learned INTEGER;
    v_perfect_scores INTEGER;
    v_cards_collected INTEGER;
    v_current_tier_ordinal INTEGER;
    v_awarded RECORD;
    v_tier_order CONSTANT TEXT[] :=
        ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
BEGIN
    -- NO auth check — called from server-side scheduled jobs only.

    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;
    SELECT COUNT(*) INTO v_vocab_learned
    FROM vocabulary_progress WHERE user_id = p_user_id AND status = 'mastered';
    SELECT COUNT(*) INTO v_perfect_scores
    FROM activity_results WHERE user_id = p_user_id AND score = max_score;
    SELECT COUNT(*) INTO v_cards_collected
    FROM user_cards WHERE user_id = p_user_id;
    v_current_tier_ordinal := COALESCE(
        array_position(v_tier_order, v_profile.league_tier), 0
    );

    FOR v_awarded IN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT p_user_id, b.id
        FROM badges b
        WHERE b.is_active = TRUE
        AND NOT EXISTS (
            SELECT 1 FROM user_badges ub
            WHERE ub.user_id = p_user_id AND ub.badge_id = b.id
        )
        AND (
            (b.condition_type = 'xp_total' AND v_profile.xp >= b.condition_value) OR
            (b.condition_type = 'streak_days' AND v_profile.current_streak >= b.condition_value) OR
            (b.condition_type = 'books_completed' AND v_books_completed >= b.condition_value) OR
            (b.condition_type = 'vocabulary_learned' AND v_vocab_learned >= b.condition_value) OR
            (b.condition_type = 'perfect_scores' AND v_perfect_scores >= b.condition_value) OR
            (b.condition_type = 'level_completed' AND v_profile.level >= b.condition_value) OR
            (b.condition_type = 'cards_collected'
                AND v_cards_collected >= b.condition_value) OR
            (b.condition_type = 'myth_category_completed'
                AND b.condition_param IS NOT NULL
                AND (
                    SELECT COUNT(*) FROM user_cards uc
                    JOIN myth_cards mc ON mc.id = uc.card_id
                    WHERE uc.user_id = p_user_id
                      AND mc.category = b.condition_param
                ) >= b.condition_value) OR
            (b.condition_type = 'league_tier_reached'
                AND b.condition_param IS NOT NULL
                AND v_current_tier_ordinal >=
                    COALESCE(array_position(v_tier_order, b.condition_param), 0)
                AND v_current_tier_ordinal > 0)
        )
        ON CONFLICT DO NOTHING
        RETURNING user_badges.badge_id
    LOOP
        SELECT b.id, b.name, b.icon, b.xp_reward
        INTO badge_id, badge_name, badge_icon, xp_reward
        FROM badges b WHERE b.id = v_awarded.badge_id;

        IF xp_reward > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, xp_reward, 'badge', v_awarded.badge_id,
                'Earned: ' || badge_name
            );
        END IF;

        RETURN NEXT;
    END LOOP;
END;
$$;

-- Revoke from anon/authenticated — only other DEFINER functions should call this
REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM anon;
REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM authenticated;

COMMENT ON FUNCTION check_and_award_badges_system IS
    'System-invoked badge check (no auth). Called from scheduled jobs and server-side RPCs.';
```

**Note on duplication:** Yes, the two functions are duplicated. This is a deliberate trade-off: the existing `check_and_award_badges` is exposed via PostgREST to the client and MUST keep the auth check. Splitting into a shared SQL helper + two thin wrappers would be cleaner long-term but expands scope. Current duplication is the minimal safe change. A follow-up refactor ticket can DRY this.

- [ ] **Step 3: Dry-run**

Run: `supabase db push --dry-run`

Expected: shows pending migration, no errors.

- [ ] **Step 4: Push**

Run: `supabase db push`

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260414000004_league_reset_badge_trigger.sql
git commit -m "feat(badges): trigger badge check after weekly league reset"
```

---

## Task 4: DB Migration — Seed 24 New Badges

**Files:**
- Create: `supabase/migrations/20260414000005_seed_card_and_league_badges.sql`

**Context:** 4 total-card + 16 category (8 × 2 milestones) + 4 tier = 24 badges. Category counts confirmed: each category has exactly 12 cards (48 across 8 = 96 total).

- [ ] **Step 1: Create migration file**

Create `supabase/migrations/20260414000005_seed_card_and_league_badges.sql`:

```sql
-- =============================================
-- Seed: Card Collection + League Tier badges
-- 4 total-card + 16 category (half + full) + 4 tier = 24 badges
-- Slugs are stable so re-runs are idempotent via ON CONFLICT DO NOTHING.
-- =============================================

INSERT INTO badges (name, slug, description, icon, category, condition_type, condition_value, condition_param, xp_reward, is_active) VALUES
-- --------- Total Cards ---------
('Koleksiyoncu Çırağı', 'card-collector-10',
 '10 farklı kart topla.', '🎴', 'achievement',
 'cards_collected', 10, NULL, 50, TRUE),
('Kart Ustası', 'card-collector-20',
 '20 farklı kart topla.', '🃏', 'achievement',
 'cards_collected', 20, NULL, 100, TRUE),
('Kart Koleksiyoncusu', 'card-collector-50',
 '50 farklı kart topla.', '🎭', 'achievement',
 'cards_collected', 50, NULL, 250, TRUE),
('Efsane Koleksiyoncu', 'card-collector-96',
 '96 kartın tamamını topla.', '👑', 'achievement',
 'cards_collected', 96, NULL, 1000, TRUE),

-- --------- Turkish Myths (12 cards) ---------
('Türk Mitleri Yarı Yolda', 'myth-turkish-6',
 'Türk Mitleri kategorisinden 6 kart topla.', '🇹🇷', 'achievement',
 'myth_category_completed', 6, 'turkish_myths', 100, TRUE),
('Türk Mitleri Ustası', 'myth-turkish-12',
 'Türk Mitleri kategorisinin tamamını topla (12 kart).', '🏛️', 'achievement',
 'myth_category_completed', 12, 'turkish_myths', 300, TRUE),

-- --------- Ancient Greece ---------
('Antik Yunan Yarı Yolda', 'myth-greece-6',
 'Antik Yunan kategorisinden 6 kart topla.', '⚡', 'achievement',
 'myth_category_completed', 6, 'ancient_greece', 100, TRUE),
('Antik Yunan Ustası', 'myth-greece-12',
 'Antik Yunan kategorisinin tamamını topla (12 kart).', '🏺', 'achievement',
 'myth_category_completed', 12, 'ancient_greece', 300, TRUE),

-- --------- Viking / Ice Lands ---------
('Viking Yarı Yolda', 'myth-viking-6',
 'Viking & Buz Diyarları kategorisinden 6 kart topla.', '⚔️', 'achievement',
 'myth_category_completed', 6, 'viking_ice_lands', 100, TRUE),
('Viking Ustası', 'myth-viking-12',
 'Viking & Buz Diyarları kategorisinin tamamını topla (12 kart).', '🛡️', 'achievement',
 'myth_category_completed', 12, 'viking_ice_lands', 300, TRUE),

-- --------- Egyptian Deserts ---------
('Mısır Yarı Yolda', 'myth-egypt-6',
 'Mısır Çölleri kategorisinden 6 kart topla.', '🐫', 'achievement',
 'myth_category_completed', 6, 'egyptian_deserts', 100, TRUE),
('Mısır Ustası', 'myth-egypt-12',
 'Mısır Çölleri kategorisinin tamamını topla (12 kart).', '🔺', 'achievement',
 'myth_category_completed', 12, 'egyptian_deserts', 300, TRUE),

-- --------- Far East ---------
('Uzak Doğu Yarı Yolda', 'myth-fareast-6',
 'Uzak Doğu kategorisinden 6 kart topla.', '🐉', 'achievement',
 'myth_category_completed', 6, 'far_east', 100, TRUE),
('Uzak Doğu Ustası', 'myth-fareast-12',
 'Uzak Doğu kategorisinin tamamını topla (12 kart).', '🎋', 'achievement',
 'myth_category_completed', 12, 'far_east', 300, TRUE),

-- --------- Medieval Magic ---------
('Ortaçağ Büyüsü Yarı Yolda', 'myth-medieval-6',
 'Ortaçağ Büyüsü kategorisinden 6 kart topla.', '🔮', 'achievement',
 'myth_category_completed', 6, 'medieval_magic', 100, TRUE),
('Ortaçağ Büyüsü Ustası', 'myth-medieval-12',
 'Ortaçağ Büyüsü kategorisinin tamamını topla (12 kart).', '🧙', 'achievement',
 'myth_category_completed', 12, 'medieval_magic', 300, TRUE),

-- --------- Legendary Weapons ---------
('Silah Yarı Yolda', 'myth-weapons-6',
 'Efsanevi Silahlar kategorisinden 6 kart topla.', '🗡️', 'achievement',
 'myth_category_completed', 6, 'legendary_weapons', 100, TRUE),
('Silah Ustası', 'myth-weapons-12',
 'Efsanevi Silahlar kategorisinin tamamını topla (12 kart).', '⚔️', 'achievement',
 'myth_category_completed', 12, 'legendary_weapons', 300, TRUE),

-- --------- Dark Creatures ---------
('Karanlık Yaratıklar Yarı Yolda', 'myth-dark-6',
 'Karanlık Yaratıklar kategorisinden 6 kart topla.', '👻', 'achievement',
 'myth_category_completed', 6, 'dark_creatures', 100, TRUE),
('Karanlık Yaratıklar Ustası', 'myth-dark-12',
 'Karanlık Yaratıklar kategorisinin tamamını topla (12 kart).', '🦇', 'achievement',
 'myth_category_completed', 12, 'dark_creatures', 300, TRUE),

-- --------- League Tier (condition_value is a placeholder — not used in evaluation) ---------
('Silver Ligci', 'league-tier-silver',
 'Silver lige yüksel.', '🥈', 'achievement',
 'league_tier_reached', 1, 'silver', 150, TRUE),
('Gold Ligci', 'league-tier-gold',
 'Gold lige yüksel.', '🥇', 'achievement',
 'league_tier_reached', 1, 'gold', 300, TRUE),
('Platinum Ligci', 'league-tier-platinum',
 'Platinum lige yüksel.', '💎', 'achievement',
 'league_tier_reached', 1, 'platinum', 600, TRUE),
('Diamond Ligci', 'league-tier-diamond',
 'Diamond lige yüksel.', '🌟', 'achievement',
 'league_tier_reached', 1, 'diamond', 1200, TRUE)

ON CONFLICT (slug) DO NOTHING;
```

- [ ] **Step 2: Dry-run**

Run: `supabase db push --dry-run`

Expected: shows pending migration, no CHECK constraint violation.

- [ ] **Step 3: Push**

Run: `supabase db push`

- [ ] **Step 4: Verify seed**

Run in Supabase SQL editor:

```sql
SELECT condition_type, COUNT(*)
FROM badges
WHERE condition_type IN ('cards_collected','myth_category_completed','league_tier_reached')
GROUP BY condition_type;
```

Expected:
```
cards_collected          | 4
myth_category_completed  | 16
league_tier_reached      | 4
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260414000005_seed_card_and_league_badges.sql
git commit -m "feat(badges): seed 24 card collection and league tier badges"
```

---

## Task 5: Shared Enum — 3 New Condition Types

**Files:**
- Modify: `packages/owlio_shared/lib/src/enums/badge_condition_type.dart`

- [ ] **Step 1: Add enum values**

Replace the enum declaration in `packages/owlio_shared/lib/src/enums/badge_condition_type.dart`:

```dart
/// Types of conditions that can trigger badge awards.
enum BadgeConditionType {
  xpTotal('xp_total'),
  streakDays('streak_days'),
  booksCompleted('books_completed'),
  vocabularyLearned('vocabulary_learned'),
  perfectScores('perfect_scores'),
  levelCompleted('level_completed'),
  cardsCollected('cards_collected'),
  mythCategoryCompleted('myth_category_completed'),
  leagueTierReached('league_tier_reached');

  final String dbValue;

  const BadgeConditionType(this.dbValue);

  /// Parse from database string (snake_case).
  static BadgeConditionType fromDbValue(String value) {
    return BadgeConditionType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => BadgeConditionType.xpTotal,
    );
  }

  /// True if this condition type requires a `condition_param` string
  /// (category slug, tier name, etc.) in addition to `condition_value`.
  bool get requiresParam => switch (this) {
        BadgeConditionType.mythCategoryCompleted => true,
        BadgeConditionType.leagueTierReached => true,
        _ => false,
      };
}
```

- [ ] **Step 2: Verify analyzer**

Run: `cd packages/owlio_shared && dart analyze lib/`

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add packages/owlio_shared/lib/src/enums/badge_condition_type.dart
git commit -m "feat(shared): add 3 new BadgeConditionType values"
```

---

## Task 6: Domain Badge Entity — `conditionParam` Field

**Files:**
- Modify: `lib/domain/entities/badge.dart`

- [ ] **Step 1: Add field to `Badge` entity**

Replace the content of `lib/domain/entities/badge.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

export 'package:owlio_shared/src/enums/badge_condition_type.dart';

class Badge extends Equatable {
  const Badge({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.category,
    required this.conditionType,
    required this.conditionValue,
    this.conditionParam,
    this.xpReward = 0,
    this.isActive = true,
    required this.createdAt,
  });
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? category;
  final BadgeConditionType conditionType;
  final int conditionValue;
  final String? conditionParam;
  final int xpReward;
  final bool isActive;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        icon,
        category,
        conditionType,
        conditionValue,
        conditionParam,
        xpReward,
        isActive,
        createdAt,
      ];
}

class UserBadge extends Equatable {
  const UserBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.badge,
    required this.earnedAt,
  });
  final String id;
  final String userId;
  final String badgeId;
  final Badge badge;
  final DateTime earnedAt;

  @override
  List<Object?> get props => [id, userId, badgeId, badge, earnedAt];
}
```

- [ ] **Step 2: Verify analyzer**

Run: `dart analyze lib/domain/`

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/domain/entities/badge.dart
git commit -m "feat(domain): add conditionParam to Badge entity"
```

---

## Task 7: BadgeModel — `condition_param` JSON Serialization

**Files:**
- Modify: `lib/data/models/badge/badge_model.dart`

- [ ] **Step 1: Add field to model**

Replace the content of `lib/data/models/badge/badge_model.dart`:

```dart
import '../../../domain/entities/badge.dart';

/// Model for Badge entity - handles JSON serialization
class BadgeModel {
  const BadgeModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.category,
    required this.conditionType,
    required this.conditionValue,
    this.conditionParam,
    this.xpReward = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      conditionType: json['condition_type'] as String? ?? 'xp_total',
      conditionValue: json['condition_value'] as int? ?? 0,
      conditionParam: json['condition_param'] as String?,
      xpReward: json['xp_reward'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory BadgeModel.fromEntity(Badge entity) {
    return BadgeModel(
      id: entity.id,
      name: entity.name,
      slug: entity.slug,
      description: entity.description,
      icon: entity.icon,
      category: entity.category,
      conditionType: conditionTypeToString(entity.conditionType),
      conditionValue: entity.conditionValue,
      conditionParam: entity.conditionParam,
      xpReward: entity.xpReward,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? category;
  final String conditionType;
  final int conditionValue;
  final String? conditionParam;
  final int xpReward;
  final bool isActive;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'category': category,
      'condition_type': conditionType,
      'condition_value': conditionValue,
      'condition_param': conditionParam,
      'xp_reward': xpReward,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Badge toEntity() {
    return Badge(
      id: id,
      name: name,
      slug: slug,
      description: description,
      icon: icon,
      category: category,
      conditionType: parseConditionType(conditionType),
      conditionValue: conditionValue,
      conditionParam: conditionParam,
      xpReward: xpReward,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  static BadgeConditionType parseConditionType(String type) {
    return BadgeConditionType.fromDbValue(type);
  }

  static String conditionTypeToString(BadgeConditionType type) {
    return type.dbValue;
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `dart analyze lib/data/models/badge/`

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/models/badge/badge_model.dart
git commit -m "feat(data): serialize condition_param in BadgeModel"
```

---

## Task 8: Admin Helpers — Labels for 3 New Types

**Files:**
- Modify: `owlio_admin/lib/core/utils/badge_helpers.dart`

- [ ] **Step 1: Extend both switch blocks**

Replace the content of `owlio_admin/lib/core/utils/badge_helpers.dart`:

```dart
// Shared badge condition helpers for admin panel.
// Covers all 9 condition types.

/// Short label for badge cards.
/// For param-based types, the second argument can optionally pass the param
/// to produce a richer label (e.g. "Gold lig").
String getConditionLabel(String type, int value, [String? param]) {
  return switch (type) {
    'xp_total' => '$value XP',
    'streak_days' => '$value gün',
    'books_completed' => '$value kitap',
    'vocabulary_learned' => '$value kelime',
    'perfect_scores' => '$value tam puan',
    'level_completed' => '$value seviye',
    'cards_collected' => '$value kart',
    'myth_category_completed' =>
        param != null ? '$param: $value kart' : '$value kart (kategori)',
    'league_tier_reached' =>
        param != null ? '$param lig' : 'lig yükselişi',
    _ => '$type: $value',
  };
}

/// Descriptive helper text for the edit form.
String getConditionHelper(String type) {
  return switch (type) {
    'xp_total' => 'Kullanıcının kazanması gereken toplam XP',
    'streak_days' => 'Ardışık aktif gün sayısı',
    'books_completed' => 'Tamamlanması gereken kitap sayısı',
    'vocabulary_learned' => 'Öğrenilmesi gereken kelime sayısı',
    'perfect_scores' => 'Etkinliklerde tam puan sayısı',
    'level_completed' => 'Ulaşılması gereken seviye',
    'cards_collected' => 'Toplanması gereken farklı kart sayısı',
    'myth_category_completed' =>
        'Seçili kategoriden toplanması gereken kart sayısı',
    'league_tier_reached' => 'Ulaşılması gereken lig (placeholder değer: 1)',
    _ => '',
  };
}

/// Dropdown options for myth category param (keys must match DB CHECK constraint on myth_cards.category).
const Map<String, String> mythCategoryOptions = {
  'turkish_myths': 'Türk Mitleri',
  'ancient_greece': 'Antik Yunan',
  'viking_ice_lands': 'Viking & Buz Diyarları',
  'egyptian_deserts': 'Mısır Çölleri',
  'far_east': 'Uzak Doğu',
  'medieval_magic': 'Ortaçağ Büyüsü',
  'legendary_weapons': 'Efsanevi Silahlar',
  'dark_creatures': 'Karanlık Yaratıklar',
};

/// Dropdown options for league tier param (keys must match profiles.league_tier values).
const Map<String, String> leagueTierOptions = {
  'silver': 'Silver',
  'gold': 'Gold',
  'platinum': 'Platinum',
  'diamond': 'Diamond',
};
```

- [ ] **Step 2: Verify analyzer**

Run: `cd owlio_admin && dart analyze lib/core/utils/`

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add owlio_admin/lib/core/utils/badge_helpers.dart
git commit -m "feat(admin): add condition labels and param dropdown options"
```

---

## Task 9: Admin Edit Screen — Conditional Param Dropdown

**Files:**
- Modify: `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart`

**Context:** Add `_conditionParam` state variable, extend `_conditionTypes` list with 3 new entries, and render a conditional dropdown that appears only when the selected condition type has `requiresParam == true`. Hook into load/save flow.

- [ ] **Step 1: Extend condition types list**

In `owlio_admin/lib/features/badges/screens/badge_edit_screen.dart`, replace the static `_conditionTypes` (currently line 55-62):

```dart
  static final _conditionTypes = [
    (BadgeConditionType.xpTotal.dbValue, 'Toplam Kazanılan XP'),
    (BadgeConditionType.streakDays.dbValue, 'Ardışık Aktif Gün'),
    (BadgeConditionType.booksCompleted.dbValue, 'Tamamlanan Kitaplar'),
    (BadgeConditionType.vocabularyLearned.dbValue, 'Öğrenilen Kelimeler'),
    (BadgeConditionType.perfectScores.dbValue, 'Tam Puan Etkinlik Skorları'),
    (BadgeConditionType.levelCompleted.dbValue, 'Ulaşılan Seviye'),
    (BadgeConditionType.cardsCollected.dbValue, 'Toplanan Kart Sayısı'),
    (BadgeConditionType.mythCategoryCompleted.dbValue, 'Kategori Bazlı Kart Toplama'),
    (BadgeConditionType.leagueTierReached.dbValue, 'Ulaşılan Lig'),
  ];
```

- [ ] **Step 2: Add `_conditionParam` state variable**

After the existing `String _conditionType = BadgeConditionType.xpTotal.dbValue;` line (currently line 69), add:

```dart
  String? _conditionParam;  // Holds category slug or tier name for param-based types
```

- [ ] **Step 3: Load `condition_param` from DB**

In `_loadBadge()` (currently lines 88-107), inside the `setState` block after `_category = badge['category'] ?? 'achievement';`, add:

```dart
        _conditionParam = badge['condition_param'] as String?;
```

- [ ] **Step 4: Add param to save payload**

In `_handleSave()` (currently lines 129-184), inside the `data` map (currently lines 137-146), add after `'condition_value'`:

```dart
        'condition_param': _conditionParam,
```

Also: when `_conditionType` is param-based (`mythCategoryCompleted` or `leagueTierReached`) and `_conditionParam` is null or empty, validate and abort with a snackbar. Insert this check at the start of `_handleSave` before the `final supabase = ...` line:

```dart
    final ct = BadgeConditionType.fromDbValue(_conditionType);
    if (ct.requiresParam && (_conditionParam == null || _conditionParam!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu koşul türü için parametre seçimi zorunludur.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
```

- [ ] **Step 5: Reset param on condition type change**

In the existing `DropdownButtonFormField<String>` for condition type (currently lines 376-392), replace the `onChanged` block:

```dart
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _conditionType = value;
                                  final newCt = BadgeConditionType.fromDbValue(value);
                                  // Reset param when switching to a type that doesn't need it,
                                  // or when switching between two param types.
                                  if (!newCt.requiresParam) {
                                    _conditionParam = null;
                                  } else {
                                    // Default to first option of new param set
                                    if (newCt == BadgeConditionType.mythCategoryCompleted) {
                                      _conditionParam ??= mythCategoryOptions.keys.first;
                                      // If previous value was a tier, reset
                                      if (!mythCategoryOptions.containsKey(_conditionParam)) {
                                        _conditionParam = mythCategoryOptions.keys.first;
                                      }
                                    } else if (newCt == BadgeConditionType.leagueTierReached) {
                                      _conditionParam ??= leagueTierOptions.keys.first;
                                      if (!leagueTierOptions.containsKey(_conditionParam)) {
                                        _conditionParam = leagueTierOptions.keys.first;
                                      }
                                    }
                                  }
                                });
                              }
                            },
```

- [ ] **Step 6: Render conditional param dropdown**

Directly after the Condition Type `DropdownButtonFormField` (ends at line ~393) and before the `SizedBox(height: 16)` that precedes "Condition value", insert:

```dart
                          // Conditional param dropdown (only when condition type needs it)
                          if (BadgeConditionType.fromDbValue(_conditionType).requiresParam) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _conditionParam,
                              decoration: const InputDecoration(
                                labelText: 'Parametre',
                                helperText: 'Bu koşulun hedeflediği kategori / lig',
                              ),
                              items: (_conditionType == BadgeConditionType.mythCategoryCompleted.dbValue
                                      ? mythCategoryOptions
                                      : leagueTierOptions)
                                  .entries
                                  .map((e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _conditionParam = value);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Parametre zorunludur';
                                }
                                return null;
                              },
                            ),
                          ],
```

Ensure the necessary import is present at the top of the file (add if missing):

```dart
import '../../../core/utils/badge_helpers.dart';
```

(It should already be imported at line 8 — verify before adding.)

- [ ] **Step 7: Update condition value helper line**

The `Koşul Değeri` field's `helperText` already calls `getConditionHelper(_conditionType)` — no change needed. But when the type is `league_tier_reached`, the value is just a placeholder (stored as `1`). Adjust the TextFormField's label to make this clear by replacing:

```dart
                          TextFormField(
                            controller: _conditionValueController,
                            decoration: InputDecoration(
                              labelText: 'Koşul Değeri',
                              hintText: 'ör. 100',
                              helperText: getConditionHelper(_conditionType),
                            ),
```

with:

```dart
                          TextFormField(
                            controller: _conditionValueController,
                            decoration: InputDecoration(
                              labelText: _conditionType == 'league_tier_reached'
                                  ? 'Koşul Değeri (lig için 1 bırakın)'
                                  : 'Koşul Değeri',
                              hintText: 'ör. 100',
                              helperText: getConditionHelper(_conditionType),
                            ),
```

- [ ] **Step 8: Verify analyzer**

Run: `cd owlio_admin && dart analyze lib/features/badges/`

Expected: `No issues found!`

- [ ] **Step 9: Manual smoke test**

Run: `cd owlio_admin && flutter run -d chrome`

Navigate to `/badges/new`:
- Select "Toplanan Kart Sayısı" → no param dropdown, condition_value field shows "Toplanması gereken farklı kart sayısı"
- Select "Kategori Bazlı Kart Toplama" → param dropdown appears with 8 categories, default "Türk Mitleri"
- Select "Ulaşılan Lig" → param dropdown shows 4 tiers, value field label becomes "Koşul Değeri (lig için 1 bırakın)"
- Save a test badge with category "Antik Yunan", value 3, XP 25 — verify it appears in the badge list with correct label ("ancient_greece: 3 kart")
- Edit an existing seeded category badge (e.g., "Türk Mitleri Ustası") — the param dropdown should be pre-populated with "Türk Mitleri"

- [ ] **Step 10: Commit**

```bash
git add owlio_admin/lib/features/badges/screens/badge_edit_screen.dart
git commit -m "feat(admin): conditional param dropdown for new badge condition types"
```

---

## Task 10: Documentation — Update Badge Spec

**Files:**
- Modify: `docs/specs/11-badge-achievement.md`

- [ ] **Step 1: Update the "Condition Types" table**

In the existing "Condition Types" table (section "### Condition Types"), add three new rows after `level_completed`:

| Type | DB Value | Evaluated Against |
|------|----------|-------------------|
| Cards Collected | `cards_collected` | COUNT of `user_cards` WHERE user_id |
| Myth Category Completed | `myth_category_completed` | COUNT of `user_cards JOIN myth_cards` WHERE category = condition_param |
| League Tier Reached | `league_tier_reached` | `profiles.league_tier` ordinal ≥ condition_param ordinal |

- [ ] **Step 2: Add new trigger chains**

Under "### Trigger Chains" section, append:

```
Card pack opening
  → open_card_pack RPC
    → UPSERT user_cards
    → PERFORM check_and_award_badges(p_user_id) (at end, before RETURN)
      → cards_collected / myth_category_completed badges may fire
```

```
Weekly league reset (scheduled)
  → process_weekly_league_reset RPC
    → per user: UPDATE profiles.league_tier, INSERT league_history
    → PERFORM check_and_award_badges_system(user_id)  (no auth — scheduled job)
      → league_tier_reached badges may fire
```

- [ ] **Step 3: Add `badges.condition_param` to the badges table definition**

In the "### Tables" section's `badges` table, add a new row:

| condition_param | VARCHAR(50) NULL | Optional string parameter (category slug, tier name) |

- [ ] **Step 4: Add seeded badges to the list**

Append a "### Seeded Card + League Badges (24 new)" subsection with the 24 badges from Task 4 summarized in a table form.

- [ ] **Step 5: Add to Key Files**

Under "### Database" in the Key Files section, append:

```
- `supabase/migrations/20260414000002_extend_badge_conditions.sql` — condition_param column + 3 new condition types
- `supabase/migrations/20260414000003_card_pack_badge_trigger.sql` — card pack trigger
- `supabase/migrations/20260414000004_league_reset_badge_trigger.sql` — league reset trigger + check_and_award_badges_system
- `supabase/migrations/20260414000005_seed_card_and_league_badges.sql` — 24 new seed badges
```

- [ ] **Step 6: Commit**

```bash
git add docs/specs/11-badge-achievement.md
git commit -m "docs(badges): document card + league condition types and triggers"
```

---

## Task 11: End-to-End Smoke Test

**Files:** (no file changes — verification only)

- [ ] **Step 1: Verify `dart analyze` is clean across both apps**

Run in parallel:
```bash
dart analyze lib/
cd owlio_admin && dart analyze lib/
cd packages/owlio_shared && dart analyze lib/
```

Expected: All three show `No issues found!`

- [ ] **Step 2: Student-side end-to-end — card badge**

In the main app (`flutter run -d chrome`):
1. Log in as `fresh@demo.com` (Test1234) — has 0 cards.
2. Grant enough coins via admin panel or SQL for one pack (`UPDATE profiles SET coins = 200 WHERE username = 'fresh';`).
3. Open a card pack via UI.
4. Observe: pack reveal shows 3 cards. If all 3 are distinct and 10+ were already owned, the `Koleksiyoncu Çırağı` badge appears in the notification overlay.
5. Navigate to Profile → Recent Badges section shows the new badge.

- [ ] **Step 3: Student-side end-to-end — category badge**

Via SQL in Supabase editor (faster than playing through pack opens):
```sql
-- Give fresh@demo.com 6 distinct turkish_myths cards
INSERT INTO user_cards (user_id, card_id, quantity)
SELECT
    (SELECT id FROM profiles WHERE username = 'fresh'),
    mc.id,
    1
FROM myth_cards mc
WHERE mc.category = 'turkish_myths' AND mc.is_active = TRUE
ORDER BY mc.card_no
LIMIT 6
ON CONFLICT (user_id, card_id) DO NOTHING;

-- Trigger badge check manually
SELECT * FROM check_and_award_badges(
    (SELECT id FROM profiles WHERE username = 'fresh')
);
```

Expected: Returns `Türk Mitleri Yarı Yolda` with 100 XP reward. `xp_logs` gets a new row with source='badge'.

- [ ] **Step 4: League tier end-to-end**

```sql
-- Promote fresh user to silver tier
UPDATE profiles SET league_tier = 'silver' WHERE username = 'fresh';

-- Trigger system badge check (from server context; normally the league reset RPC does this)
SELECT * FROM check_and_award_badges_system(
    (SELECT id FROM profiles WHERE username = 'fresh')
);
```

Expected: Returns `Silver Ligci` with 150 XP reward.

- [ ] **Step 5: Admin CRUD end-to-end**

In admin panel:
1. Navigate to `/badges`.
2. Click "Yeni Rozet" / create.
3. Set icon 🎯, name "Test Rozeti", condition type "Kategori Bazlı Kart Toplama", param "Antik Yunan", value 3, XP 25.
4. Save. Verify it appears in `badges` table with condition_param = 'ancient_greece'.
5. Edit the same badge — param dropdown pre-populated with "Antik Yunan".
6. Delete the test badge.

- [ ] **Step 6: Idempotency check**

Run the manual trigger twice:
```sql
SELECT * FROM check_and_award_badges(auth.uid());
SELECT * FROM check_and_award_badges(auth.uid());
```

Expected: Second call returns 0 rows (UNIQUE constraint prevents re-award).

- [ ] **Step 7: Final cleanup commit (if any doc tweaks)**

```bash
git status
# If anything stray, commit with "chore: final tidy".
```

---

## Completion Criteria

- [ ] 4 migrations pushed successfully (`supabase migration list` shows all 4)
- [ ] `dart analyze` clean in all 3 packages
- [ ] Admin can create, edit, delete a badge of each new condition type
- [ ] Student earns a card-based badge by opening a pack (observed via notification + profile)
- [ ] Student earns a category milestone badge by reaching the threshold
- [ ] Student earns a league tier badge after weekly reset (or manual tier update)
- [ ] Spec doc `11-badge-achievement.md` reflects new reality
- [ ] No regressions in existing badge flows (XP, streak, books, vocabulary, perfect_scores, level) — verified by earning at least one existing badge after push

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Migration breaks existing `check_and_award_badges` callers | Return type unchanged; only OR-branch additions. Existing callers are transparent to new types. |
| Scheduled league reset has no `auth.uid()` | Separate `check_and_award_badges_system` variant without auth check, REVOKE from public roles. |
| Duplicate function bodies (`_system` variant) drift | Comment in both functions references each other; follow-up ticket to DRY via shared sub-function. |
| Large category badge count overwhelms notification queue | Notification card already supports multi-badge layout (`NotificationCard.badgeEarned(badges: List<BadgeEarned>)`). Unchanged. |
| Admin form regression for existing 6 condition types | Conditional dropdown only renders when `requiresParam == true`; existing types render identically. |
| Card pack RPC body copied imperfectly | Task 2 explicitly requires reading the latest version and copy-paste — no paraphrase. Reviewer must diff `20260328200001` vs new file and confirm only the `PERFORM` line is added. |
| Admin helper signature change breaks callers | Task 8 changes `getConditionLabel(type, value)` to `getConditionLabel(type, value, [param])`. The third param is optional so existing call sites (badge list screen) still compile — but grep `getConditionLabel` before merging to confirm no positional issues. |
| `profiles.league_tier` NULL for fresh users | `array_position` returns NULL for NULL input, `COALESCE` coerces to 0, and `v_current_tier_ordinal > 0` guard ensures tier badges never fire for null-tier users. Documented in Task 1 step 1 inline. |

---

## Rollback Plan

Remote Supabase migrations are hard to roll back. If any migration causes production issues:

1. **Migration 4 (seed)**: `DELETE FROM badges WHERE slug LIKE 'card-collector-%' OR slug LIKE 'myth-%' OR slug LIKE 'league-tier-%';` — cascade drops `user_badges` for those badges.
2. **Migration 3 (league trigger)**: Reapply the prior `process_weekly_league_reset` body from `20260407000006` without the `PERFORM` line.
3. **Migration 2 (card trigger)**: Reapply the prior `open_card_pack` body from `20260328200001` without the `PERFORM` line.
4. **Migration 1 (schema + RPC)**: Reapply `check_and_award_badges` from `20260328000008`. Drop `condition_param` column: `ALTER TABLE badges DROP COLUMN condition_param;`. Restore CHECK constraint to the original 7 values.

All rollbacks are manual migrations, each pushed with `supabase db push`.
