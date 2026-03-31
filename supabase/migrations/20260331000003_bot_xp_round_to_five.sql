-- Round bot XP values to multiples of 5 for realism.

CREATE OR REPLACE FUNCTION bot_weekly_xp_target(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text));
    v_min INTEGER;
    v_max INTEGER;
    v_raw INTEGER;
BEGIN
    CASE p_xp_bucket
        WHEN 0 THEN v_min := 20;  v_max := 80;
        WHEN 1 THEN v_min := 30;  v_max := 99;
        WHEN 2 THEN v_min := 100; v_max := 299;
        WHEN 3 THEN v_min := 300; v_max := 599;
        WHEN 4 THEN v_min := 600; v_max := 1000;
        ELSE         v_min := 20;  v_max := 80;
    END CASE;
    v_raw := v_min + (v_seed % (v_max - v_min + 1));
    RETURN (v_raw / 5) * 5;  -- round down to nearest multiple of 5
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION bot_current_xp(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER,
    p_week_start DATE
) RETURNS INTEGER AS $$
DECLARE
    v_target INTEGER := bot_weekly_xp_target(p_group_id, p_slot, p_xp_bucket);
    v_elapsed FLOAT := EXTRACT(EPOCH FROM (app_now() - p_week_start::timestamptz)) / (7.0 * 86400);
    v_day_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text || '_' || EXTRACT(DOW FROM app_now())::text));
    v_jitter FLOAT := (v_day_seed % 20 - 10) / 100.0;
    v_raw INTEGER;
BEGIN
    v_elapsed := GREATEST(0, LEAST(1, v_elapsed));
    v_raw := LEAST(v_target, GREATEST(0, (v_target * (v_elapsed + v_jitter))::INTEGER));
    RETURN (v_raw / 5) * 5;  -- round down to nearest multiple of 5
END;
$$ LANGUAGE plpgsql STABLE;
