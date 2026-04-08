# League Reset System Fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the weekly league reset to run reliably, handle missed weeks, harden edge function auth, and align client-side "days left" with UTC.

**Architecture:** Five independent fixes: (1) SQL catch-up loop so missed weeks are processed retroactively, (2) Supabase cron to replace unreliable external cron-job.org, (3) edge function auth hardening, (4) client-side UTC alignment for "days left", (5) verify end-to-end.

**Tech Stack:** PostgreSQL (Supabase migration), Deno (Edge Function), Dart/Flutter (client)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `supabase/migrations/2026XXXXXX_league_reset_catchup.sql` | Rewrite reset RPC with catch-up loop + strict auth |
| Modify | `supabase/functions/league-reset/index.ts` | Remove weak auth bypass |
| Modify | `lib/presentation/widgets/shell/right_info_panel.dart` | UTC-based "days left" |
| — | (cron-job.org) | Verify/fix external cron schedule |

---

### Task 1: SQL — Catch-Up Loop for Missed Weeks

The current `process_weekly_league_reset()` only processes `current_week - 7 days`. If the cron misses a Monday, that week is permanently lost. Rewrite to loop from the oldest unprocessed week up to last week.

**Files:**
- Create: `supabase/migrations/2026XXXXXX_league_reset_catchup.sql`

- [ ] **Step 1: Write the migration**

Timestamp will be determined at creation time. Use the next available slot.

```sql
-- League Reset Catch-Up: process all missed weeks, not just last week
-- Also hardens edge function auth (removes falsy-secret bypass)

CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_this_week DATE := date_trunc('week', app_now())::DATE;
    v_target_week DATE;
    v_target_week_ts TIMESTAMPTZ;
    v_next_week_ts TIMESTAMPTZ;
    v_group RECORD;
    v_total_bots INTEGER := (SELECT count(*)::INTEGER FROM bot_profiles);
    v_bot_count INTEGER;
    v_zone_size INTEGER;
    v_entry RECORD;
    v_new_tier VARCHAR(20);
    v_result VARCHAR(20);
    v_tier_order TEXT[] := ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
    v_tier_idx INTEGER;
BEGIN
    -- Find the oldest unprocessed week: earliest league_groups.week_start with processed=false
    -- that is strictly before this week (don't process current week — it's still active)
    SELECT MIN(lg.week_start) INTO v_target_week
    FROM league_groups lg
    WHERE lg.processed = false AND lg.week_start < v_this_week;

    -- If no unprocessed groups, still check inactive decay for last week only
    IF v_target_week IS NULL THEN
        v_target_week := v_this_week - 7;
    END IF;

    -- Loop from oldest unprocessed week through last week
    WHILE v_target_week < v_this_week LOOP
        v_target_week_ts := v_target_week::TIMESTAMPTZ;
        v_next_week_ts := (v_target_week + 7)::TIMESTAMPTZ;

        -- Pre-aggregate weekly XP for this target week
        DROP TABLE IF EXISTS tmp_weekly_xp;
        CREATE TEMP TABLE tmp_weekly_xp AS
        SELECT xl.user_id, COALESCE(SUM(xl.amount), 0)::BIGINT AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_target_week_ts AND xl.created_at < v_next_week_ts
        GROUP BY xl.user_id;
        CREATE INDEX idx_tmp_wx_user ON tmp_weekly_xp(user_id);

        -- Process each unprocessed group for this week
        FOR v_group IN
            SELECT * FROM league_groups
            WHERE week_start = v_target_week AND processed = false
            FOR UPDATE
        LOOP
            v_bot_count := GREATEST(0, 30 - v_group.member_count);
            v_zone_size := 5;

            FOR v_entry IN
                WITH real_entries AS (
                    SELECT
                        p.id AS entry_id,
                        COALESCE(wxc.week_xp, 0)::BIGINT AS entry_weekly_xp,
                        p.xp AS entry_total_xp,
                        p.league_tier AS entry_tier,
                        lgm.school_id AS entry_school_id,
                        p.class_id AS entry_class_id,
                        FALSE AS entry_is_bot
                    FROM league_group_members lgm
                    JOIN profiles p ON lgm.user_id = p.id
                    LEFT JOIN tmp_weekly_xp wxc ON p.id = wxc.user_id
                    WHERE lgm.group_id = v_group.id
                ),
                bot_entries AS (
                    SELECT
                        ('00000000-0000-0000-0000-' || LPAD(bp.id::text, 12, '0'))::UUID AS entry_id,
                        bot_weekly_xp_target(v_group.id, slot_num, v_group.xp_bucket)::BIGINT AS entry_weekly_xp,
                        0::INTEGER AS entry_total_xp,
                        v_group.tier AS entry_tier,
                        NULL::UUID AS entry_school_id,
                        NULL::UUID AS entry_class_id,
                        TRUE AS entry_is_bot
                    FROM generate_series(0, v_bot_count - 1) AS slot_num
                    JOIN bot_profiles bp ON bp.id = (abs(hashtext(v_group.id::text || '_slot_' || slot_num::text)) % v_total_bots) + 1
                    WHERE v_bot_count > 0 AND v_total_bots > 0
                ),
                all_entries AS (
                    SELECT * FROM real_entries UNION ALL SELECT * FROM bot_entries
                ),
                ranked AS (
                    SELECT *, RANK() OVER (ORDER BY entry_weekly_xp DESC, entry_total_xp DESC)::INTEGER AS entry_rank
                    FROM all_entries
                )
                SELECT * FROM ranked ORDER BY entry_rank
            LOOP
                IF v_entry.entry_is_bot THEN CONTINUE; END IF;

                v_result := 'stayed';
                v_new_tier := v_entry.entry_tier;
                v_tier_idx := array_position(v_tier_order, v_entry.entry_tier);

                IF v_zone_size > 0 AND v_entry.entry_rank <= v_zone_size AND v_tier_idx < 5 THEN
                    v_new_tier := v_tier_order[v_tier_idx + 1];
                    v_result := 'promoted';
                ELSIF v_zone_size > 0 AND v_entry.entry_rank > (30 - v_zone_size) AND v_tier_idx > 1 THEN
                    v_new_tier := v_tier_order[v_tier_idx - 1];
                    v_result := 'demoted';
                END IF;

                INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result, group_id)
                VALUES (v_entry.entry_id, v_entry.entry_class_id, v_entry.entry_school_id,
                        v_target_week, v_new_tier, v_entry.entry_rank, v_entry.entry_weekly_xp, v_result, v_group.id)
                ON CONFLICT (user_id, week_start) DO NOTHING;

                IF v_new_tier != v_entry.entry_tier THEN
                    UPDATE profiles SET league_tier = v_new_tier WHERE id = v_entry.entry_id;
                END IF;
            END LOOP;

            UPDATE league_groups SET processed = true WHERE id = v_group.id;
        END LOOP;

        -- Inactive tier decay for this week (4+ weeks without joining)
        INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
        SELECT p.id, p.class_id, p.school_id, v_target_week,
               CASE p.league_tier
                   WHEN 'diamond' THEN 'platinum'
                   WHEN 'platinum' THEN 'gold'
                   WHEN 'gold' THEN 'silver'
                   WHEN 'silver' THEN 'bronze'
                   ELSE p.league_tier
               END,
               0, 0, 'inactive_demoted'
        FROM profiles p
        WHERE p.role = 'student'
        AND p.league_tier != 'bronze'
        AND NOT EXISTS (
            SELECT 1 FROM league_group_members lgm
            WHERE lgm.user_id = p.id
            AND lgm.week_start >= (v_target_week - 28)::DATE
        )
        AND NOT EXISTS (
            SELECT 1 FROM league_history lh
            WHERE lh.user_id = p.id AND lh.week_start = v_target_week
        );

        UPDATE profiles SET league_tier = CASE league_tier
            WHEN 'diamond' THEN 'platinum'
            WHEN 'platinum' THEN 'gold'
            WHEN 'gold' THEN 'silver'
            WHEN 'silver' THEN 'bronze'
            ELSE league_tier
        END
        WHERE role = 'student'
        AND league_tier != 'bronze'
        AND NOT EXISTS (
            SELECT 1 FROM league_group_members lgm
            WHERE lgm.user_id = profiles.id
            AND lgm.week_start >= (v_target_week - 28)::DATE
        )
        AND NOT EXISTS (
            SELECT 1 FROM league_history lh
            WHERE lh.user_id = profiles.id AND lh.week_start = v_target_week
        );

        -- Advance to next week
        v_target_week := v_target_week + 7;
    END LOOP;

    -- Cleanup old groups (> 8 weeks)
    DELETE FROM league_groups
    WHERE week_start < (v_this_week - 56)::DATE;

    DROP TABLE IF EXISTS tmp_weekly_xp;
END;
$$;
```

Key changes from the previous version:
1. **Catch-up WHILE loop** — iterates from oldest unprocessed `league_groups.week_start` through `this_week - 7`. If cron missed 3 Mondays, all 3 weeks get processed in one call.
2. **`ON CONFLICT DO NOTHING`** on `league_history` INSERT — idempotency guard on the `(user_id, week_start)` unique constraint instead of a pre-check query.
3. **`DROP TABLE IF EXISTS` + recreate temp table per iteration** — the old version used `CREATE TEMP TABLE IF NOT EXISTS` which would retain stale data across loop iterations.
4. **Inactive decay uses `v_target_week` window** — not `app_now()`, so missed weeks get correct 28-day lookback relative to THAT week.

- [ ] **Step 2: Dry-run the migration**

```bash
supabase db push --dry-run
```

Expected: Shows the migration will be applied. No errors.

- [ ] **Step 3: Push the migration**

```bash
supabase db push
```

- [ ] **Step 4: Verify by calling the RPC**

```bash
curl -s -X POST "https://wqkxjjakysuabjcotvim.supabase.co/rest/v1/rpc/process_weekly_league_reset" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  --max-time 30 -w "\nHTTP Status: %{http_code}"
```

Expected: HTTP 204 (no content, void return). Should be idempotent — no duplicate history rows.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_league_reset_catchup.sql
git commit -m "fix(db): league reset catch-up loop for missed weeks

Rewrites process_weekly_league_reset() to iterate from the oldest
unprocessed league_groups week through last week, so missed cron
runs don't permanently lose promotion/demotion data. Adds ON CONFLICT
idempotency and fixes temp table reuse across iterations."
```

---

### Task 2: Edge Function Auth Hardening

The current auth check bypasses if `CRON_SECRET` env var is unset (falsy `expectedSecret` short-circuits the `&&`). Fix to require the secret always.

**Files:**
- Modify: `supabase/functions/league-reset/index.ts`

- [ ] **Step 1: Fix the auth check**

In `supabase/functions/league-reset/index.ts`, replace the auth block:

```typescript
// OLD (line 19-22):
// const cronSecret = req.headers.get('x-cron-secret')
// const expectedSecret = Deno.env.get('CRON_SECRET')
// if (expectedSecret && cronSecret !== expectedSecret) {

// NEW:
const cronSecret = req.headers.get('x-cron-secret')
const expectedSecret = Deno.env.get('CRON_SECRET')

if (!expectedSecret || cronSecret !== expectedSecret) {
```

This changes behavior: if `CRON_SECRET` is not set, ALL requests are rejected (fail-closed) instead of all requests being accepted (fail-open).

- [ ] **Step 2: Deploy the edge function**

```bash
supabase functions deploy league-reset
```

- [ ] **Step 3: Verify auth rejection works**

```bash
# Should return 401 (no secret header)
curl -s -X POST "https://wqkxjjakysuabjcotvim.supabase.co/functions/v1/league-reset" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json"
```

Expected: `{"error":"Unauthorized"}` with HTTP 401.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/league-reset/index.ts
git commit -m "fix(edge): fail-closed auth on league-reset edge function

Previously, if CRON_SECRET env var was unset, the auth check was
bypassed (fail-open). Now rejects all requests unless secret matches."
```

---

### Task 3: Client-Side UTC "Days Left" Fix

The `_LeagueCard` calculates "days left" using `DateTime.now()` (local time). The league resets at Monday 00:00 UTC. For a UTC+3 user on Sunday 23:00 local time, the league has already reset (Monday 02:00 local > Monday 00:00 UTC) but the widget still shows "1 day left".

**Files:**
- Modify: `lib/presentation/widgets/shell/right_info_panel.dart` (~line 189-193)

- [ ] **Step 1: Fix the days-left calculation to use UTC**

In the `_LeagueCard` build method, replace:

```dart
// OLD:
final now = DateTime.now();
final weekEnd = now
    .subtract(Duration(days: now.weekday - 1))
    .add(const Duration(days: 6));
final daysLeft = weekEnd.difference(now).inDays + 1;
```

with:

```dart
// NEW — use UTC to match server-side week boundaries
final now = DateTime.now().toUtc();
final weekEnd = now
    .subtract(Duration(days: now.weekday - 1))
    .add(const Duration(days: 6));
final daysLeft = weekEnd.difference(now).inDays + 1;
```

- [ ] **Step 2: Run analyzer**

```bash
dart analyze lib/presentation/widgets/shell/right_info_panel.dart
```

Expected: No new warnings (pre-existing warnings are OK).

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/shell/right_info_panel.dart
git commit -m "fix(ui): use UTC for league 'days left' calculation

DateTime.now() used local time, misaligning with the server-side
Monday 00:00 UTC reset boundary by up to ±12 hours."
```

---

### Task 4: Verify/Fix cron-job.org Schedule

The external cron at cron-job.org must call the edge function every Monday 00:00 UTC with the correct `x-cron-secret` header.

**Files:** None (external service configuration)

- [ ] **Step 1: Log into cron-job.org and verify the job exists**

Check for a job targeting:
```
POST https://wqkxjjakysuabjcotvim.supabase.co/functions/v1/league-reset
```

Verify:
- **Schedule:** Every Monday at 00:00 UTC (cron: `0 0 * * 1`)
- **Method:** POST
- **Headers:** Must include `x-cron-secret: <actual CRON_SECRET value>`
- **Enabled:** Job must be active (not paused)

- [ ] **Step 2: If missing or misconfigured, create/fix the job**

Required configuration:
- URL: `https://wqkxjjakysuabjcotvim.supabase.co/functions/v1/league-reset`
- Method: POST
- Schedule: `0 0 * * 1` (Monday 00:00 UTC)
- Headers: `x-cron-secret: <value from Supabase secrets>`
- Request timeout: 30 seconds
- Notifications: Enable failure alerts to admin email

- [ ] **Step 3: Test the cron by triggering a manual run from cron-job.org**

Use the "Test run" / "Run now" button on cron-job.org. Check the response is `{"success":true,"message":"Weekly league reset completed"}`.

- [ ] **Step 4: Document the cron setup**

No code commit needed, but note the cron-job.org job ID for future reference.

---

### Task 5: End-to-End Verification

- [ ] **Step 1: Verify current league_history is consistent**

```bash
# Check that all league_groups with week_start < this_week are processed
curl -s "https://wqkxjjakysuabjcotvim.supabase.co/rest/v1/league_groups?select=week_start,tier,processed&processed=eq.false&week_start=lt.2026-04-06" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```

Expected: Empty array `[]` — no unprocessed groups for past weeks.

- [ ] **Step 2: Verify tier distribution is reasonable**

```bash
curl -s "https://wqkxjjakysuabjcotvim.supabase.co/rest/v1/profiles?select=league_tier&role=eq.student" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```

Check that tiers are distributed (not all bronze or all diamond).

- [ ] **Step 3: Verify the app shows correct league data**

Log in as `active@demo.com` (password: `Test1234`) and navigate to leaderboard:
- League tab should show current week group with bots
- "X days left" should reflect UTC-based countdown
- Tier label should match the profile's current `league_tier`

- [ ] **Step 4: Final commit with docs update**

```bash
git add -A
git commit -m "fix(league): reset catch-up, auth hardening, UTC days-left

- SQL: catch-up loop processes all missed weeks, not just last week
- Edge function: fail-closed auth (rejects if CRON_SECRET unset)
- Client: UTC-based 'days left' countdown
- Cron: verified on cron-job.org (Monday 00:00 UTC)"
```
