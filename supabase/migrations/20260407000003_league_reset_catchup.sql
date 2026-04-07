-- =============================================
-- Catch-up loop for process_weekly_league_reset()
-- =============================================
-- Problem: The old version only processed (current_week - 7 days).
-- If the Monday cron missed a run, that week was permanently lost.
-- Fix: Loop from the oldest unprocessed week up to last week.

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
BEGIN
    -- Find oldest unprocessed week that is before the current week
    SELECT MIN(week_start) INTO v_oldest_unprocessed
    FROM league_groups
    WHERE processed = false AND week_start < v_this_week;

    -- If nothing to process, just run inactive decay for last week and cleanup
    IF v_oldest_unprocessed IS NULL THEN
        v_target_week := v_this_week - 7;

        -- Inactive tier decay for last week only
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
        ON CONFLICT (user_id, week_start) DO NOTHING;

        UPDATE profiles SET league_tier = CASE league_tier
            WHEN 'diamond' THEN 'platinum'
            WHEN 'platinum' THEN 'gold'
            WHEN 'gold' THEN 'silver'
            WHEN 'silver' THEN 'bronze'
            ELSE league_tier
        END
        WHERE role = 'student'
        AND league_tier != 'bronze'
        AND NOT EXISTS (
            SELECT 1 FROM league_group_members lgm
            WHERE lgm.user_id = profiles.id
            AND lgm.week_start >= (v_target_week - INTERVAL '21 days')::DATE
        );

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
            END LOOP;

            UPDATE league_groups SET processed = true WHERE id = v_group.id;
        END LOOP;

        -- Inactive tier decay for this target week
        -- 28-day lookback is relative to the target week, not app_now()
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
        ON CONFLICT (user_id, week_start) DO NOTHING;

        -- Update profiles for inactive decay (after history capture)
        UPDATE profiles SET league_tier = CASE league_tier
            WHEN 'diamond' THEN 'platinum'
            WHEN 'platinum' THEN 'gold'
            WHEN 'gold' THEN 'silver'
            WHEN 'silver' THEN 'bronze'
            ELSE league_tier
        END
        WHERE role = 'student'
        AND league_tier != 'bronze'
        AND NOT EXISTS (
            SELECT 1 FROM league_group_members lgm
            WHERE lgm.user_id = profiles.id
            AND lgm.week_start >= (v_target_week - INTERVAL '21 days')::DATE
        );

        v_target_week := v_target_week + 7;
    END LOOP;

    -- Cleanup old groups (> 8 weeks)
    DELETE FROM league_groups
    WHERE week_start < (date_trunc('week', app_now()) - INTERVAL '8 weeks')::DATE;

    DROP TABLE IF EXISTS tmp_weekly_xp;
END;
$$;
