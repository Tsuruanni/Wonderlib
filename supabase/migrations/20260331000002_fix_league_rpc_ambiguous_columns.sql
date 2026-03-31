-- Fix ambiguous column references in league RPCs.
-- PostgreSQL PL/pgSQL treats RETURNS TABLE columns as variables inside the function body.
-- When the table being queried has the same column name (e.g., user_id, group_id),
-- PostgreSQL raises "column reference is ambiguous". Fix by using table aliases.

-- =============================================
-- Fix 1: get_league_group_leaderboard
-- =============================================
CREATE OR REPLACE FUNCTION get_league_group_leaderboard(
    p_group_id UUID,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR,
    school_name VARCHAR,
    is_same_school BOOLEAN,
    is_bot BOOLEAN,
    group_member_count INTEGER,
    previous_group_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_group RECORD;
    v_total_bots INTEGER;
    v_bot_count INTEGER;
    v_caller_school_id UUID;
    v_week_start_ts TIMESTAMPTZ;
    v_prev_week_start DATE;
BEGIN
    -- Auth check: caller must be a member of this group
    -- Use table alias to avoid ambiguity with RETURNS TABLE columns
    IF NOT EXISTS (
        SELECT 1 FROM league_group_members lgm_auth
        WHERE lgm_auth.group_id = p_group_id AND lgm_auth.user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: caller is not a member of this group';
    END IF;

    -- Fetch group info once
    SELECT * INTO v_group FROM league_groups WHERE id = p_group_id FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group not found';
    END IF;

    v_total_bots := (SELECT count(*)::INTEGER FROM bot_profiles);
    v_bot_count := GREATEST(0, 30 - v_group.member_count);
    v_week_start_ts := v_group.week_start::timestamptz;
    v_prev_week_start := (v_group.week_start - INTERVAL '7 days')::DATE;

    SELECT p.school_id INTO v_caller_school_id FROM profiles p WHERE p.id = auth.uid();

    IF v_total_bots = 0 THEN
        -- No bot profiles, return only real entries
        RETURN QUERY
        WITH weekly_xp_calc AS (
            SELECT xl.user_id AS uid, COALESCE(SUM(xl.amount), 0) AS week_xp
            FROM xp_logs xl WHERE xl.created_at >= v_week_start_ts GROUP BY xl.user_id
        ),
        prev_week AS (
            SELECT lh.user_id AS uid, lh.rank AS prev_rank, lh.group_id AS prev_group_id
            FROM league_history lh WHERE lh.week_start = v_prev_week_start
        ),
        real_entries AS (
            SELECT
                p.id AS e_user_id, p.first_name AS e_first_name, p.last_name AS e_last_name,
                p.avatar_url AS e_avatar_url, p.avatar_equipped_cache AS e_avatar_equipped_cache,
                p.xp AS e_total_xp, COALESCE(wxc.week_xp, 0)::BIGINT AS e_weekly_xp,
                p.level AS e_level, pw.prev_rank AS e_previous_rank, pw.prev_group_id AS e_prev_group_id,
                p.league_tier AS e_league_tier, s.name AS e_school_name,
                (p.school_id = v_caller_school_id) AS e_is_same_school, FALSE AS e_is_bot
            FROM league_group_members lgm
            JOIN profiles p ON lgm.user_id = p.id
            LEFT JOIN schools s ON p.school_id = s.id
            LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
            LEFT JOIN prev_week pw ON p.id = pw.uid
            WHERE lgm.group_id = p_group_id
        ),
        ranked AS (
            SELECT *, RANK() OVER (ORDER BY e_weekly_xp DESC, e_total_xp DESC) AS e_rank FROM real_entries
        )
        SELECT r.e_user_id, r.e_first_name, r.e_last_name, r.e_avatar_url,
               r.e_avatar_equipped_cache, r.e_total_xp::INTEGER, r.e_weekly_xp,
               r.e_level::INTEGER, r.e_rank, r.e_previous_rank,
               r.e_league_tier, r.e_school_name, r.e_is_same_school, r.e_is_bot,
               v_group.member_count::INTEGER, r.e_prev_group_id
        FROM ranked r ORDER BY r.e_rank LIMIT p_limit;
        RETURN;
    END IF;

    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT xl.user_id AS uid, COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl WHERE xl.created_at >= v_week_start_ts GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT lh.user_id AS uid, lh.rank AS prev_rank, lh.group_id AS prev_group_id
        FROM league_history lh WHERE lh.week_start = v_prev_week_start
    ),
    real_entries AS (
        SELECT
            p.id AS e_user_id, p.first_name AS e_first_name, p.last_name AS e_last_name,
            p.avatar_url AS e_avatar_url, p.avatar_equipped_cache AS e_avatar_equipped_cache,
            p.xp AS e_total_xp, COALESCE(wxc.week_xp, 0)::BIGINT AS e_weekly_xp,
            p.level AS e_level, pw.prev_rank AS e_previous_rank, pw.prev_group_id AS e_prev_group_id,
            p.league_tier AS e_league_tier, s.name AS e_school_name,
            (p.school_id = v_caller_school_id) AS e_is_same_school, FALSE AS e_is_bot
        FROM league_group_members lgm
        JOIN profiles p ON lgm.user_id = p.id
        LEFT JOIN schools s ON p.school_id = s.id
        LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
        LEFT JOIN prev_week pw ON p.id = pw.uid
        WHERE lgm.group_id = p_group_id
    ),
    bot_entries AS (
        SELECT
            ('00000000-0000-0000-0000-' || LPAD(bp.id::text, 12, '0'))::UUID AS e_user_id,
            bp.first_name AS e_first_name, bp.last_name AS e_last_name,
            NULL::VARCHAR AS e_avatar_url, bp.avatar_equipped_cache AS e_avatar_equipped_cache,
            0 AS e_total_xp,
            bot_current_xp(p_group_id, slot_num, v_group.xp_bucket, v_group.week_start)::BIGINT AS e_weekly_xp,
            GREATEST(1, bot_weekly_xp_target(p_group_id, slot_num, v_group.xp_bucket) / 50 + 1) AS e_level,
            NULL::INTEGER AS e_previous_rank, NULL::UUID AS e_prev_group_id,
            v_group.tier AS e_league_tier, bp.school_name AS e_school_name,
            FALSE AS e_is_same_school, TRUE AS e_is_bot
        FROM generate_series(0, v_bot_count - 1) AS slot_num
        JOIN bot_profiles bp ON bp.id = (abs(hashtext(p_group_id::text || '_slot_' || slot_num::text)) % v_total_bots) + 1
        WHERE v_bot_count > 0
    ),
    all_entries AS (SELECT * FROM real_entries UNION ALL SELECT * FROM bot_entries),
    ranked AS (
        SELECT *, RANK() OVER (ORDER BY e_weekly_xp DESC, e_total_xp DESC) AS e_rank FROM all_entries
    )
    SELECT r.e_user_id, r.e_first_name, r.e_last_name, r.e_avatar_url,
           r.e_avatar_equipped_cache, r.e_total_xp::INTEGER, r.e_weekly_xp,
           r.e_level::INTEGER, r.e_rank, r.e_previous_rank,
           r.e_league_tier, r.e_school_name, r.e_is_same_school, r.e_is_bot,
           30::INTEGER, r.e_prev_group_id
    FROM ranked r ORDER BY r.e_rank LIMIT p_limit;
END;
$$;

-- =============================================
-- Fix 2: get_user_league_status
-- =============================================
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
    current_weekly_xp BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_week_start DATE := date_trunc('week', app_now())::DATE;
    v_week_start_ts TIMESTAMPTZ := date_trunc('week', app_now());
    v_current_weekly_xp BIGINT;
    v_group_id UUID;
    v_user_tier VARCHAR(20);
    v_group_bucket INTEGER;
    v_group_member_count INTEGER;
    v_total_bots INTEGER;
    v_bot_count INTEGER;
    v_user_rank BIGINT;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied: user mismatch';
    END IF;

    -- Get current weekly XP
    SELECT COALESCE(SUM(xl.amount), 0) INTO v_current_weekly_xp
    FROM xp_logs xl
    WHERE xl.user_id = p_user_id AND xl.created_at >= v_week_start_ts;

    -- Get user's tier (use alias to avoid ambiguity with RETURNS TABLE 'tier')
    SELECT p.league_tier INTO v_user_tier FROM profiles p WHERE p.id = p_user_id;

    -- Check if in a group (use alias to avoid ambiguity with RETURNS TABLE 'group_id', 'week_start')
    SELECT lgm.group_id INTO v_group_id
    FROM league_group_members lgm
    WHERE lgm.user_id = p_user_id AND lgm.week_start = v_week_start;

    IF v_group_id IS NULL THEN
        RETURN QUERY SELECT
            NULL::UUID, NULL::INTEGER, v_user_tier, v_week_start,
            v_current_weekly_xp, NULL::BIGINT,
            FALSE, (v_current_weekly_xp >= 20),
            v_current_weekly_xp;
        RETURN;
    END IF;

    -- Get group info for bot generation
    SELECT lg.xp_bucket, lg.member_count INTO v_group_bucket, v_group_member_count
    FROM league_groups lg WHERE lg.id = v_group_id;

    v_total_bots := (SELECT count(*)::INTEGER FROM bot_profiles);
    v_bot_count := GREATEST(0, 30 - v_group_member_count);

    -- Compute rank using same bot-merge pattern (inlined)
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
        TRUE, TRUE, v_current_weekly_xp;
END;
$$;
