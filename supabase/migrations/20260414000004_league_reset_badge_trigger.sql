-- =============================================
-- League Reset Badge Trigger
-- 1. Add check_and_award_badges_system (no-auth variant for scheduled jobs)
-- 2. Rewrite process_weekly_league_reset to call badge check per user after tier update
-- =============================================

-- -----------------------------------------------
-- Part A: check_and_award_badges_system
-- Identical to check_and_award_badges but with the auth check removed.
-- Called from scheduled jobs and server-side RPCs that run without auth.uid().
-- -----------------------------------------------
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
    -- NOTE: Auth check intentionally omitted — this variant is for system/scheduled callers.

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

COMMENT ON FUNCTION check_and_award_badges_system IS
    'System-invoked badge check (no auth). Called from scheduled jobs and server-side RPCs.';

REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM anon;
REVOKE ALL ON FUNCTION check_and_award_badges_system(UUID) FROM authenticated;

-- -----------------------------------------------
-- Part B: process_weekly_league_reset — badge check injected after each tier update
-- -----------------------------------------------
CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_this_week DATE := (date_trunc('week', app_now()))::DATE;
    v_oldest_unprocessed DATE;
    v_target_week DATE;
    v_target_week_ts TIMESTAMPTZ;
    v_next_week_ts TIMESTAMPTZ;
    v_group RECORD;
    v_total_bots INTEGER := (SELECT count(*)::INTEGER FROM bot_profiles);
    v_bot_count INTEGER;
    v_zone_size INTEGER;
    v_entry RECORD;
    v_new_tier VARCHAR(20);
    v_result VARCHAR(20);
    v_tier_order TEXT[] := ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
    v_tier_idx INTEGER;
    v_decay_user RECORD;
BEGIN
    -- Find oldest unprocessed week that is before the current week
    SELECT MIN(week_start) INTO v_oldest_unprocessed
    FROM league_groups
    WHERE processed = false AND week_start < v_this_week;

    -- If nothing to process, just run inactive decay for last week and cleanup
    IF v_oldest_unprocessed IS NULL THEN
        v_target_week := v_this_week - 7;

        -- Inactive tier decay for last week only
        -- INSERT ... RETURNING ensures UPDATE only affects newly-inserted users
        -- (ON CONFLICT DO NOTHING returns nothing for skipped rows → idempotent)
        WITH decayed AS (
            INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
            SELECT p.id, p.class_id, p.school_id, v_target_week,
                   CASE p.league_tier
                       WHEN 'diamond' THEN 'platinum'
                       WHEN 'platinum' THEN 'gold'
                       WHEN 'gold' THEN 'silver'
                       WHEN 'silver' THEN 'bronze'
                       ELSE p.league_tier
                   END,
                   0, 0, 'inactive_demoted'
            FROM profiles p
            WHERE p.role = 'student'
            AND p.league_tier != 'bronze'
            AND NOT EXISTS (
                SELECT 1 FROM league_group_members lgm
                WHERE lgm.user_id = p.id
                AND lgm.week_start >= (v_target_week - INTERVAL '21 days')::DATE
            )
            ON CONFLICT (user_id, week_start) DO NOTHING
            RETURNING user_id
        )
        UPDATE profiles SET league_tier = CASE league_tier
            WHEN 'diamond' THEN 'platinum'
            WHEN 'platinum' THEN 'gold'
            WHEN 'gold' THEN 'silver'
            WHEN 'silver' THEN 'bronze'
            ELSE league_tier
        END
        WHERE id IN (SELECT user_id FROM decayed);

        -- Badge check for each inactive-demoted user (new tier now visible in profiles)
        FOR v_decay_user IN
            SELECT user_id FROM league_history
            WHERE week_start = v_target_week AND result = 'inactive_demoted'
        LOOP
            BEGIN
                PERFORM check_and_award_badges_system(v_decay_user.user_id);
            EXCEPTION WHEN OTHERS THEN
                NULL; -- badge failure must not roll back league reset
            END;
        END LOOP;

        -- Cleanup old groups (> 8 weeks)
        DELETE FROM league_groups
        WHERE week_start < (date_trunc('week', app_now()) - INTERVAL '8 weeks')::DATE;

        RETURN;
    END IF;

    -- Loop from oldest unprocessed week through last week
    v_target_week := v_oldest_unprocessed;

    WHILE v_target_week < v_this_week LOOP
        v_target_week_ts := v_target_week::TIMESTAMPTZ;
        v_next_week_ts := (v_target_week + 7)::TIMESTAMPTZ;

        -- Fresh temp table each iteration (drop first to avoid stale data)
        DROP TABLE IF EXISTS tmp_weekly_xp;
        CREATE TEMP TABLE tmp_weekly_xp AS
        SELECT xl.user_id, COALESCE(SUM(xl.amount), 0)::BIGINT AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_target_week_ts AND xl.created_at < v_next_week_ts
        GROUP BY xl.user_id;
        CREATE INDEX idx_tmp_wx_user ON tmp_weekly_xp(user_id);

        -- Process each unprocessed group for this target week
        FOR v_group IN
            SELECT * FROM league_groups
            WHERE week_start = v_target_week AND processed = false
            FOR UPDATE
        LOOP
            v_bot_count := GREATEST(0, 30 - v_group.member_count);

            -- Zone size: with virtual bots, display count is always 30 -> zone = 5
            v_zone_size := 5;

            -- Rank real + bot entries together
            FOR v_entry IN
                WITH real_entries AS (
                    SELECT
                        p.id AS entry_id,
                        COALESCE(wxc.week_xp, 0)::BIGINT AS entry_weekly_xp,
                        p.xp AS entry_total_xp,
                        p.league_tier AS entry_tier,
                        lgm.school_id AS entry_school_id,
                        p.class_id AS entry_class_id,
                        FALSE AS entry_is_bot
                    FROM league_group_members lgm
                    JOIN profiles p ON lgm.user_id = p.id
                    LEFT JOIN tmp_weekly_xp wxc ON p.id = wxc.user_id
                    WHERE lgm.group_id = v_group.id
                ),
                bot_entries AS (
                    SELECT
                        ('00000000-0000-0000-0000-' || LPAD(bp.id::text, 12, '0'))::UUID AS entry_id,
                        bot_weekly_xp_target(v_group.id, slot_num, v_group.xp_bucket)::BIGINT AS entry_weekly_xp,
                        0::INTEGER AS entry_total_xp,
                        v_group.tier AS entry_tier,
                        NULL::UUID AS entry_school_id,
                        NULL::UUID AS entry_class_id,
                        TRUE AS entry_is_bot
                    FROM generate_series(0, v_bot_count - 1) AS slot_num
                    JOIN bot_profiles bp ON bp.id = (abs(hashtext(v_group.id::text || '_slot_' || slot_num::text)) % v_total_bots) + 1
                    WHERE v_bot_count > 0 AND v_total_bots > 0
                ),
                all_entries AS (
                    SELECT * FROM real_entries UNION ALL SELECT * FROM bot_entries
                ),
                ranked AS (
                    SELECT *, RANK() OVER (ORDER BY entry_weekly_xp DESC, entry_total_xp DESC)::INTEGER AS entry_rank
                    FROM all_entries
                )
                SELECT * FROM ranked ORDER BY entry_rank
            LOOP
                -- Skip bots entirely
                IF v_entry.entry_is_bot THEN CONTINUE; END IF;

                v_result := 'stayed';
                v_new_tier := v_entry.entry_tier;
                v_tier_idx := array_position(v_tier_order, v_entry.entry_tier);

                -- Promotion zone (top 5)
                IF v_zone_size > 0 AND v_entry.entry_rank <= v_zone_size AND v_tier_idx < 5 THEN
                    v_new_tier := v_tier_order[v_tier_idx + 1];
                    v_result := 'promoted';
                -- Demotion zone (bottom 5, i.e., rank > 25 out of 30)
                ELSIF v_zone_size > 0 AND v_entry.entry_rank > (30 - v_zone_size) AND v_tier_idx > 1 THEN
                    v_new_tier := v_tier_order[v_tier_idx - 1];
                    v_result := 'demoted';
                END IF;

                INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result, group_id)
                VALUES (v_entry.entry_id, v_entry.entry_class_id, v_entry.entry_school_id,
                        v_target_week, v_new_tier, v_entry.entry_rank, v_entry.entry_weekly_xp, v_result, v_group.id)
                ON CONFLICT (user_id, week_start) DO NOTHING;

                IF v_new_tier != v_entry.entry_tier THEN
                    UPDATE profiles SET league_tier = v_new_tier WHERE id = v_entry.entry_id;
                END IF;

                -- Badge check: runs after profiles.league_tier UPDATE so new tier is visible.
                -- Wrapped in EXCEPTION block so badge failures don't roll back league reset.
                BEGIN
                    PERFORM check_and_award_badges_system(v_entry.entry_id);
                EXCEPTION WHEN OTHERS THEN
                    NULL; -- badge failure must not roll back league reset
                END;
            END LOOP;

            UPDATE league_groups SET processed = true WHERE id = v_group.id;
        END LOOP;

        -- Inactive tier decay for this target week
        -- INSERT ... RETURNING ensures UPDATE only affects newly-inserted users
        WITH decayed AS (
            INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
            SELECT p.id, p.class_id, p.school_id, v_target_week,
                   CASE p.league_tier
                       WHEN 'diamond' THEN 'platinum'
                       WHEN 'platinum' THEN 'gold'
                       WHEN 'gold' THEN 'silver'
                       WHEN 'silver' THEN 'bronze'
                       ELSE p.league_tier
                   END,
                   0, 0, 'inactive_demoted'
            FROM profiles p
            WHERE p.role = 'student'
            AND p.league_tier != 'bronze'
            AND NOT EXISTS (
                SELECT 1 FROM league_group_members lgm
                WHERE lgm.user_id = p.id
                AND lgm.week_start >= (v_target_week - INTERVAL '21 days')::DATE
            )
            AND NOT EXISTS (
                SELECT 1 FROM league_history lh
                WHERE lh.user_id = p.id AND lh.week_start = v_target_week
            )
            ON CONFLICT (user_id, week_start) DO NOTHING
            RETURNING user_id
        )
        UPDATE profiles SET league_tier = CASE league_tier
            WHEN 'diamond' THEN 'platinum'
            WHEN 'platinum' THEN 'gold'
            WHEN 'gold' THEN 'silver'
            WHEN 'silver' THEN 'bronze'
            ELSE league_tier
        END
        WHERE id IN (SELECT user_id FROM decayed);

        -- Badge check for each inactive-demoted user (new tier now visible in profiles)
        FOR v_decay_user IN
            SELECT user_id FROM league_history
            WHERE week_start = v_target_week AND result = 'inactive_demoted'
        LOOP
            BEGIN
                PERFORM check_and_award_badges_system(v_decay_user.user_id);
            EXCEPTION WHEN OTHERS THEN
                NULL; -- badge failure must not roll back league reset
            END;
        END LOOP;

        v_target_week := v_target_week + 7;
    END LOOP;

    -- Cleanup old groups (> 8 weeks)
    DELETE FROM league_groups
    WHERE week_start < (date_trunc('week', app_now()) - INTERVAL '8 weeks')::DATE;

    DROP TABLE IF EXISTS tmp_weekly_xp;
END;
$$;
