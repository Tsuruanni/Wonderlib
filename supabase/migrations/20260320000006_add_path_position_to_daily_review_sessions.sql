-- Add path_position to daily_review_sessions so completed DR stays at its injection point
ALTER TABLE daily_review_sessions
  ADD COLUMN path_position INTEGER;
