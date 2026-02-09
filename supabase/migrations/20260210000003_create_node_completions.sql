-- Track completion of special path nodes (flipbook, daily_review, game, treasure)
-- Used for sequential lock progression in the learning path

CREATE TABLE user_node_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  unit_id UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  node_type TEXT NOT NULL CHECK (node_type IN ('flipbook', 'daily_review', 'game', 'treasure')),
  completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, unit_id, node_type)
);

-- RLS
ALTER TABLE user_node_completions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own node completions"
  ON user_node_completions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own node completions"
  ON user_node_completions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Index for fast lookup by user
CREATE INDEX idx_user_node_completions_user_id ON user_node_completions(user_id);
