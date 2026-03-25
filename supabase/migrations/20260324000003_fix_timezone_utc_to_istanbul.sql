-- Fix timezone: app_current_date() and app_now() were using UTC
-- which caused a 3-hour mismatch with Turkey (UTC+3).
-- Between 00:00-03:00 local time, the server thought it was the previous day.

CREATE OR REPLACE FUNCTION app_current_date() RETURNS DATE AS $$
  SELECT ((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul')::DATE + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ))::DATE;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION app_now() RETURNS TIMESTAMPTZ AS $$
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul')::TIMESTAMPTZ + COALESCE(
    (SELECT value::INT FROM system_settings WHERE key = 'debug_date_offset'), 0
  ) * INTERVAL '1 day';
$$ LANGUAGE sql STABLE;
