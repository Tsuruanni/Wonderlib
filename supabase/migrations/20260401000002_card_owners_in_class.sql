-- Returns classmates who own a specific card (excluding the caller)
CREATE OR REPLACE FUNCTION get_card_owners_in_class(p_user_id UUID, p_card_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_id UUID;
  v_result JSONB;
BEGIN
  SELECT class_id INTO v_class_id
  FROM profiles WHERE id = p_user_id;

  IF v_class_id IS NULL THEN
    RETURN jsonb_build_object('owners', '[]'::jsonb, 'total_students', 0);
  END IF;

  WITH class_students AS (
    SELECT id, first_name
    FROM profiles
    WHERE class_id = v_class_id
      AND role = 'student'
  ),
  card_owners AS (
    SELECT cs.first_name
    FROM class_students cs
    JOIN user_cards uc ON uc.user_id = cs.id
    WHERE uc.card_id = p_card_id
      AND cs.id != p_user_id
    ORDER BY cs.first_name
  )
  SELECT jsonb_build_object(
    'owners', COALESCE((SELECT jsonb_agg(first_name) FROM card_owners), '[]'::jsonb),
    'total_students', (SELECT COUNT(*) FROM class_students) - 1
  ) INTO v_result;

  RETURN v_result;
END;
$$;
