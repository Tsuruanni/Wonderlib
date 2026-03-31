-- Fix app_now(): was returning Istanbul wall-clock time labeled as UTC.
--
-- The AT TIME ZONE 'Europe/Istanbul' conversion was originally added to fix
-- app_current_date() returning the wrong DATE near midnight (00:00-03:00 Istanbul).
-- That fix was correct for DATE (dates are inherently local), but was
-- incorrectly applied to app_now() too.
--
-- For TIMESTAMPTZ (absolute point in time), the conversion caused a systematic
-- +3 hour offset:
--   (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul')::TIMESTAMPTZ
--   = "14:30 UTC" when real UTC is 11:30
--
-- This caused a WRITE/READ mismatch:
--   WRITE: complete_vocabulary_session sets next_review_at = app_now() → 3h ahead
--   READ:  get_due_review_words checks next_review_at <= NOW()         → correct UTC
--   Result: words not due for 3 hours after being marked as "due now"
--
-- Fix: use NOW() directly (correct UTC). Keep app_current_date() unchanged
-- (Istanbul timezone is correct for date-only operations).

CREATE OR REPLACE FUNCTION app_now() RETURNS TIMESTAMPTZ AS $$
  SELECT NOW() + COALESCE(
    (SELECT (value #>> '{}')::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ) * INTERVAL '1 day';
$$ LANGUAGE sql STABLE;
