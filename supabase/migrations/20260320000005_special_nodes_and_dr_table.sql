-- =============================================
-- SPECIAL NODES + DAILY REVIEW GATE
-- =============================================

-- 1. Update CHECK constraints to allow game/treasure item types
-- Template items
ALTER TABLE learning_path_template_items
  DROP CONSTRAINT IF EXISTS learning_path_template_items_item_type_check;
ALTER TABLE learning_path_template_items
  ADD CONSTRAINT learning_path_template_items_item_type_check
    CHECK (item_type IN ('word_list', 'book', 'game', 'treasure'));

ALTER TABLE learning_path_template_items
  DROP CONSTRAINT IF EXISTS learning_path_template_items_check;
ALTER TABLE learning_path_template_items
  ADD CONSTRAINT learning_path_template_items_check CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL) OR
    (item_type IN ('game', 'treasure') AND word_list_id IS NULL AND book_id IS NULL)
  );

-- Scope items
ALTER TABLE scope_unit_items
  DROP CONSTRAINT IF EXISTS scope_unit_items_item_type_check;
ALTER TABLE scope_unit_items
  ADD CONSTRAINT scope_unit_items_item_type_check
    CHECK (item_type IN ('word_list', 'book', 'game', 'treasure'));

ALTER TABLE scope_unit_items
  DROP CONSTRAINT IF EXISTS scope_unit_items_check;
ALTER TABLE scope_unit_items
  ADD CONSTRAINT scope_unit_items_check CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL) OR
    (item_type IN ('game', 'treasure') AND word_list_id IS NULL AND book_id IS NULL)
  );

-- 2. Daily Review completion tracking
CREATE TABLE path_daily_review_completions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  scope_lp_unit_id UUID NOT NULL REFERENCES scope_learning_path_units(id) ON DELETE CASCADE,
  position         INTEGER NOT NULL,
  completed_at     DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, scope_lp_unit_id, completed_at)
);

CREATE INDEX idx_path_dr_user ON path_daily_review_completions(user_id);
CREATE INDEX idx_path_dr_unit ON path_daily_review_completions(scope_lp_unit_id);

ALTER TABLE path_daily_review_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_data" ON path_daily_review_completions
  FOR ALL USING (auth.uid() = user_id);

-- 3. RPC for fetching DR history
CREATE OR REPLACE FUNCTION get_path_daily_reviews(p_user_id UUID)
RETURNS TABLE (
  scope_lp_unit_id UUID,
  "position"       INTEGER,
  completed_at     DATE
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT scope_lp_unit_id, "position", completed_at
  FROM path_daily_review_completions
  WHERE user_id = p_user_id
  ORDER BY completed_at DESC;
$$;
