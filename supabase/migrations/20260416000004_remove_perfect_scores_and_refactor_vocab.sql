-- =============================================
-- Badge System Refactor:
--   1. Remove perfect_scores condition type entirely (badges + RPC branches + CHECK)
--   2. Refactor vocabulary_learned: count vocabulary_progress rows (word bank size)
--      instead of mastered-only. Update thresholds 10/50/200 -> 25/100/500.
--   3. Convergent backfill so all users re-evaluated.
-- =============================================

-- 1a. Delete the 2 perfect_scores badges (cascade-deletes user_badges entries)
DELETE FROM badges WHERE condition_type = 'perfect_scores';

-- 1b. Drop and recreate the CHECK constraint without perfect_scores
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
    CHECK (condition_type IN (
        'xp_total', 'streak_days', 'books_completed',
        'vocabulary_learned', 'level_completed', 'daily_login',
        'cards_collected', 'myth_category_completed', 'league_tier_reached'
    ));

-- 2a. Update vocabulary badge thresholds + descriptions
UPDATE badges SET condition_value = 25,
    description = 'Collect 25 words in your word bank.'
    WHERE slug = 'word-explorer';
UPDATE badges SET condition_value = 100,
    description = 'Collect 100 words in your word bank.'
    WHERE slug = 'vocabulary-champion';
UPDATE badges SET condition_value = 500,
    description = 'Collect 500 words in your word bank.'
    WHERE slug = 'word-master';

-- 3a. Rewrite check_and_award_badges (drop perfect_scores branch + change vocab semantics)
CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_collected INTEGER;
    v_cards_collected INTEGER;
    v_current_tier_ordinal INTEGER;
    v_awarded RECORD;
    v_tier_order CONSTANT TEXT[] :=
        ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
BEGIN
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;

    -- Word bank size: every vocabulary_progress row regardless of status.
    SELECT COUNT(*) INTO v_vocab_collected
    FROM vocabulary_progress WHERE user_id = p_user_id;

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
            (b.condition_type = 'vocabulary_learned' AND v_vocab_collected >= b.condition_value) OR
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

COMMENT ON FUNCTION check_and_award_badges IS
    'Client-callable badge evaluator with auth.uid() check. IMPORTANT: keep evaluation logic in sync with check_and_award_badges_system. When adding a new condition_type branch, edit BOTH functions.';

-- 3b. Mirror update for the system variant (no auth check)
CREATE OR REPLACE FUNCTION check_and_award_badges_system(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, badge_icon VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_collected INTEGER;
    v_cards_collected INTEGER;
    v_current_tier_ordinal INTEGER;
    v_awarded RECORD;
    v_tier_order CONSTANT TEXT[] :=
        ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
BEGIN
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;

    SELECT COUNT(*) INTO v_vocab_collected
    FROM vocabulary_progress WHERE user_id = p_user_id;

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
            (b.condition_type = 'vocabulary_learned' AND v_vocab_collected >= b.condition_value) OR
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

COMMENT ON FUNCTION check_and_award_badges_system IS
    'Server-only badge evaluator (no auth check) for scheduled jobs and SECURITY DEFINER chains. Never expose via PostgREST or grant to anon/authenticated. IMPORTANT: keep evaluation logic in sync with check_and_award_badges. When adding a new condition_type branch, edit BOTH functions.';

REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM anon;
REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM authenticated;

-- 4. Convergent backfill — re-evaluate all users now that vocab semantics changed
DO $$
DECLARE
    u RECORD;
    v_pass_count INTEGER;
    v_new_count INTEGER;
    v_total_new INTEGER := 0;
    v_max_passes CONSTANT INTEGER := 5;
BEGIN
    FOR u IN SELECT id FROM profiles LOOP
        v_pass_count := 0;
        LOOP
            v_pass_count := v_pass_count + 1;
            IF v_pass_count > v_max_passes THEN EXIT; END IF;
            BEGIN
                SELECT COUNT(*) INTO v_new_count
                FROM check_and_award_badges_system(u.id);
            EXCEPTION WHEN OTHERS THEN
                v_new_count := 0;
                EXIT;
            END;
            v_total_new := v_total_new + v_new_count;
            IF v_new_count = 0 THEN EXIT; END IF;
        END LOOP;
    END LOOP;
    RAISE NOTICE 'Vocab refactor backfill: % new badges awarded', v_total_new;
END $$;
