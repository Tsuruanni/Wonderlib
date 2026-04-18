-- =============================================
-- Allow teachers/admins to read class leaderboard positions for students
-- in their own school. Previously get_user_class_position only allowed
-- the caller to read rows for their own class.
-- =============================================

CREATE OR REPLACE FUNCTION get_user_class_position(
    p_user_id UUID,
    p_class_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_caller_school_id UUID;
    v_class_school_id UUID;
BEGIN
    -- 1) Caller is in this class (original behavior)
    IF EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        NULL;
    -- 2) Caller is a teacher/admin in the same school as the class
    ELSIF is_teacher_or_higher() THEN
        SELECT school_id INTO v_caller_school_id FROM profiles WHERE id = auth.uid();
        SELECT school_id INTO v_class_school_id FROM classes WHERE id = p_class_id;
        IF v_caller_school_id IS DISTINCT FROM v_class_school_id THEN
            RAISE EXCEPTION 'Unauthorized: class is not in your school';
        END IF;
    ELSE
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

    RETURN QUERY
    WITH ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            p.level,
            RANK() OVER (ORDER BY p.xp DESC) AS rnk,
            p.league_tier
        FROM profiles p
        WHERE p.class_id = p_class_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.level, r.rnk, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_class_position(UUID, UUID) TO authenticated;
