-- Replace external cron-job.org with database-level pg_cron
-- pg_cron is pre-installed on Supabase Cloud (just needs enabling)

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule league reset every Monday at 00:00 UTC
-- pg_cron runs in UTC by default
SELECT cron.schedule(
    'league-weekly-reset',
    '0 0 * * 1',
    $$SELECT process_weekly_league_reset()$$
);
