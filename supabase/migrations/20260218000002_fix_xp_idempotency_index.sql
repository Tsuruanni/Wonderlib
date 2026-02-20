-- Fix: XP idempotency index was blocking all XP awards after the first one
-- because source_id=NULL + COALESCE caused all NULL source_ids to collide.
-- Make the index partial: only enforce uniqueness when source_id IS NOT NULL.

DROP INDEX IF EXISTS idx_xp_logs_idempotent;

CREATE UNIQUE INDEX idx_xp_logs_idempotent
  ON xp_logs (user_id, source, source_id)
  WHERE source_id IS NOT NULL;
