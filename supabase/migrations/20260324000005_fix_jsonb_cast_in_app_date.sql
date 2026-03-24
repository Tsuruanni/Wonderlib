-- Fix JSONB cast error in app_current_date() and app_now()
-- system_settings.value is JSONB type, so "3" (quoted string) can't cast directly to INT
-- Must strip JSONB quotes first: value #>> '{}' extracts as plain text

CREATE OR REPLACE FUNCTION app_current_date() RETURNS DATE AS $$
  SELECT ((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul')::DATE + COALESCE(
    (SELECT (value #>> '{}')::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ))::DATE;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION app_now() RETURNS TIMESTAMPTZ AS $$
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul')::TIMESTAMPTZ + COALESCE(
    (SELECT (value #>> '{}')::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ) * INTERVAL '1 day';
$$ LANGUAGE sql STABLE;
