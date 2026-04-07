-- Add last week's result to get_user_league_status RPC.
-- Must DROP first because RETURNS TABLE signature is changing (new columns).

DROP FUNCTION IF EXISTS get_user_league_status(UUID);

CREATE OR REPLACE FUNCTION get_user_league_status(p_user_id UUID)
RETURNS TABLE(
    group_id UUID,
    group_member_count INTEGER,
    tier VARCHAR,
    week_start DATE,
    weekly_xp BIGINT,
    rank BIGINT,
    joined BOOLEAN,
    threshold_met BOOLEAN,
    current_weekly_xp BIGINT,
    last_week_rank INTEGER,
    last_week_result VARCHAR,
    last_week_tier VARCHAR,
    last_week_xp INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_week_start DATE := date_trunc('week', app_now())::DATE;
    v_week_start_ts TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
    v_current_weekly_xp BIGINT;
    v_group_id UUID;
    v_user_tier VARCHAR(20);
    v_group_bucket INTEGER;
    v_group_member_count INTEGER;
    v_total_bots INTEGER;
    v_bot_count INTEGER;
    v_user_rank BIGINT;
    v_lw_rank INTEGER;
    v_lw_result VARCHAR(20);
    v_lw_tier VARCHAR(20);
    v_lw_xp INTEGER;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied: user mismatch';
    END IF;

    -- Get current weekly XP
    SELECT COALESCE(SUM(xl.amount), 0) INTO v_current_weekly_xp
    FROM xp_logs xl
    WHERE xl.user_id = p_user_id AND xl.created_at >= v_week_start_ts;

    -- Get user's tier
    SELECT p.league_tier INTO v_user_tier FROM profiles p WHERE p.id = p_user_id;

    -- Get last week's result from league_history
    SELECT lh.rank, lh.result, lh.league_tier, lh.weekly_xp
    INTO v_lw_rank, v_lw_result, v_lw_tier, v_lw_xp
    FROM league_history lh
    WHERE lh.user_id = p_user_id AND lh.week_start = v_prev_week_start;

    -- Check if in a group this week
    SELECT lgm.group_id INTO v_group_id
    FROM league_group_members lgm
    WHERE lgm.user_id = p_user_id AND lgm.week_start = v_week_start;

    IF v_group_id IS NULL THEN
        RETURN QUERY SELECT
            NULL::UUID, NULL::INTEGER, v_user_tier, v_week_start,
            v_current_weekly_xp, NULL::BIGINT,
            FALSE, (v_current_weekly_xp >= 20),
            v_current_weekly_xp,
            v_lw_rank, v_lw_result, v_lw_tier, v_lw_xp;
        RETURN;
    END IF;

    -- Get group info for bot generation
    SELECT lg.xp_bucket, lg.member_count INTO v_group_bucket, v_group_member_count
    FROM league_groups lg WHERE lg.id = v_group_id;

    v_total_bots := (SELECT count(*)::INTEGER FROM bot_profiles);
    v_bot_count := GREATEST(0, 30 - v_group_member_count);

    -- Compute rank using bot-merge pattern (inlined)
    SELECT ranked.rnk INTO v_user_rank
    FROM (
        WITH weekly_xp_calc AS (
            SELECT xl.user_id AS uid, COALESCE(SUM(xl.amount), 0) AS wxp
            FROM xp_logs xl WHERE xl.created_at >= v_week_start_ts GROUP BY xl.user_id
        ),
        real_entries AS (
            SELECT p.id AS eid, COALESCE(wxc.wxp, 0)::BIGINT AS ewxp, p.xp AS etxp
            FROM league_group_members lgm
            JOIN profiles p ON lgm.user_id = p.id
            LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
            WHERE lgm.group_id = v_group_id
        ),
        bot_entries AS (
            SELECT
                ('00000000-0000-0000-0000-' || LPAD(bp.id::text, 12, '0'))::UUID AS eid,
                bot_current_xp(v_group_id, slot_num, v_group_bucket, v_week_start)::BIGINT AS ewxp,
                0::INTEGER AS etxp
            FROM generate_series(0, v_bot_count - 1) AS slot_num
            JOIN bot_profiles bp ON bp.id = (abs(hashtext(v_group_id::text || '_slot_' || slot_num::text)) % v_total_bots) + 1
            WHERE v_bot_count > 0 AND v_total_bots > 0
        ),
        all_entries AS (SELECT * FROM real_entries UNION ALL SELECT * FROM bot_entries),
        ranked_all AS (
            SELECT eid, RANK() OVER (ORDER BY ewxp DESC, etxp DESC) AS rnk FROM all_entries
        )
        SELECT * FROM ranked_all
    ) ranked
    WHERE ranked.eid = p_user_id;

    RETURN QUERY SELECT
        v_group_id, 30::INTEGER, v_user_tier, v_week_start,
        v_current_weekly_xp, v_user_rank,
        TRUE, TRUE, v_current_weekly_xp,
        v_lw_rank, v_lw_result, v_lw_tier, v_lw_xp;
END;
$$;
