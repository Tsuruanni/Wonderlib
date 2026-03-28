-- Fix misleading comments in calculate_level function.
-- Old comments said thresholds were "0, 100, 300, 600" and formula was "n*(n+1)*50".
-- Actual thresholds from the formula are "0, 200, 600, 1200, 2000" matching
-- client-side LevelHelper.xpForLevel(level) = (level-1) * level * 100.
-- Function body is UNCHANGED — only comments are corrected.

CREATE OR REPLACE FUNCTION calculate_level(p_xp INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Level thresholds: 0, 200, 600, 1200, 2000, 3000, 4200, 5600, 7200, 9000...
    -- Formula: threshold(level) = (level - 1) * level * 100
    -- Inverse: level = floor((-1 + sqrt(1 + xp/25)) / 2) + 1
    -- Must match client-side LevelHelper.xpForLevel() in level_helper.dart
    IF p_xp <= 0 THEN
        RETURN 1;
    END IF;
    RETURN LEAST(GREATEST(FLOOR((-1 + SQRT(1 + p_xp / 25.0)) / 2) + 1, 1), 100)::INTEGER;
END;
$$;

COMMENT ON FUNCTION calculate_level IS 'Calculate user level from XP using quadratic formula. Capped at 100.';
