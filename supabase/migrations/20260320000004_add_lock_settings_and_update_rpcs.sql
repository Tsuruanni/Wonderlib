-- =============================================
-- ADD LOCK SETTINGS + UPDATE RPCS
-- =============================================

-- 1. Add lock columns to template table
ALTER TABLE learning_path_templates
  ADD COLUMN sequential_lock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN books_exempt_from_lock BOOLEAN NOT NULL DEFAULT true;

-- 2. Add lock columns to scope table
ALTER TABLE scope_learning_paths
  ADD COLUMN sequential_lock BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN books_exempt_from_lock BOOLEAN NOT NULL DEFAULT true;

-- 3. Drop existing RPCs (return type changing requires drop first)
DROP FUNCTION IF EXISTS apply_learning_path_template(UUID, UUID, INTEGER, UUID, UUID);
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID);

-- 4. Recreate apply_learning_path_template with lock settings
CREATE OR REPLACE FUNCTION apply_learning_path_template(
  p_template_id UUID,
  p_school_id   UUID,
  p_grade       INTEGER DEFAULT NULL,
  p_class_id    UUID DEFAULT NULL,
  p_user_id     UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_scope_lp_id UUID;
  v_template RECORD;
  v_template_unit RECORD;
  v_scope_unit_id UUID;
  v_item RECORD;
BEGIN
  SELECT name, sequential_lock, books_exempt_from_lock
  INTO v_template
  FROM learning_path_templates
  WHERE id = p_template_id;

  IF v_template.name IS NULL THEN
    RAISE EXCEPTION 'Template not found: %', p_template_id;
  END IF;

  INSERT INTO scope_learning_paths (
    name, template_id, school_id, grade, class_id, sort_order, created_by,
    sequential_lock, books_exempt_from_lock
  )
  VALUES (
    v_template.name,
    p_template_id,
    p_school_id,
    p_grade,
    p_class_id,
    COALESCE(
      (SELECT MAX(sort_order) + 1 FROM scope_learning_paths
       WHERE school_id = p_school_id
         AND grade IS NOT DISTINCT FROM p_grade
         AND class_id IS NOT DISTINCT FROM p_class_id),
      0
    ),
    p_user_id,
    v_template.sequential_lock,
    v_template.books_exempt_from_lock
  )
  RETURNING id INTO v_scope_lp_id;

  FOR v_template_unit IN
    SELECT id, unit_id, sort_order
    FROM learning_path_template_units
    WHERE template_id = p_template_id
    ORDER BY sort_order
  LOOP
    INSERT INTO scope_learning_path_units (scope_learning_path_id, unit_id, sort_order)
    VALUES (v_scope_lp_id, v_template_unit.unit_id, v_template_unit.sort_order)
    RETURNING id INTO v_scope_unit_id;

    FOR v_item IN
      SELECT item_type, word_list_id, book_id, sort_order
      FROM learning_path_template_items
      WHERE template_unit_id = v_template_unit.id
      ORDER BY sort_order
    LOOP
      INSERT INTO scope_unit_items (scope_lp_unit_id, item_type, word_list_id, book_id, sort_order)
      VALUES (v_scope_unit_id, v_item.item_type, v_item.word_list_id, v_item.book_id, v_item.sort_order);
    END LOOP;
  END LOOP;

  RETURN v_scope_lp_id;
END;
$$;

-- 5. Recreate get_user_learning_paths with lock columns
CREATE OR REPLACE FUNCTION get_user_learning_paths(p_user_id UUID)
RETURNS TABLE (
  learning_path_id        UUID,
  learning_path_name      VARCHAR,
  lp_sort_order           INTEGER,
  sequential_lock         BOOLEAN,
  books_exempt_from_lock  BOOLEAN,
  unit_id                 UUID,
  unit_name               VARCHAR,
  unit_color              VARCHAR,
  unit_icon               VARCHAR,
  unit_sort_order         INTEGER,
  item_type               VARCHAR,
  item_id                 UUID,
  item_sort_order         INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
  v_class_id UUID;
BEGIN
  SELECT p.school_id, c.grade, p.class_id
  INTO v_school_id, v_grade, v_class_id
  FROM profiles p
  LEFT JOIN classes c ON c.id = p.class_id
  WHERE p.id = p_user_id;

  IF v_school_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    slp.id AS learning_path_id,
    slp.name::VARCHAR AS learning_path_name,
    slp.sort_order AS lp_sort_order,
    slp.sequential_lock,
    slp.books_exempt_from_lock,
    vu.id AS unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR AS item_type,
    COALESCE(sui.word_list_id, sui.book_id) AS item_id,
    sui.sort_order AS item_sort_order
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = v_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;
