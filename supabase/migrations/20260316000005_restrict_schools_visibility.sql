-- Restrict schools visibility: replace public-access-all with a lookup function
-- Previously: USING (true) exposed all columns to everyone including anonymous users
-- Now: Public can only validate school codes via RPC

-- Drop the overly permissive public policy
DROP POLICY IF EXISTS "Public can view schools by code" ON schools;

-- Create a safe function for signup school validation
CREATE OR REPLACE FUNCTION lookup_school_by_code(p_code VARCHAR)
RETURNS TABLE(school_id UUID, school_name VARCHAR)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT s.id, s.name
    FROM schools s
    WHERE s.code = p_code
    AND s.status = 'active';
END;
$$;

COMMENT ON FUNCTION lookup_school_by_code IS 'Public signup: validate school code and get name. Returns only id + name, not settings/subscription.';
