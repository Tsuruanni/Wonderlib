# League Matchmaking Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the school+tier league system with Duolingo-style cross-school matchmaking groups (~30 players), lazy join, virtual bots, and per-group promotion/demotion.

**Architecture:** Single database migration creates new tables (league_groups, league_group_members, bot_profiles), helper functions, and rewrites all league RPCs. Flutter layers follow existing clean architecture: Entity → Model → Repository → UseCase → Provider → Screen. Virtual bots are computed on-the-fly in SQL — no bot rows in member tables.

**Tech Stack:** PostgreSQL (Supabase), Flutter/Dart, Riverpod, owlio_shared package

**Spec:** `docs/superpowers/specs/2026-03-31-league-matchmaking-redesign.md`

---

## File Map

### Database
- **Create:** `supabase/migrations/2026MMDD_league_matchmaking_redesign.sql` — single migration with all schema + RPC changes

### Shared Package (`packages/owlio_shared`)
- **Modify:** `lib/src/constants/league_constants.dart` — new zone size table
- **Modify:** `lib/src/constants/rpc_functions.dart` — remove 4 old, add 3 new RPC constants

### Domain Layer
- **Modify:** `lib/domain/entities/leaderboard_entry.dart` — add isBot, schoolName, isSameSchool, groupId fields
- **Create:** `lib/domain/entities/league_status.dart` — new entity
- **Modify:** `lib/domain/repositories/user_repository.dart` — remove 4 weekly methods, add 2 new
- **Create:** `lib/domain/usecases/user/get_league_group_leaderboard_usecase.dart`
- **Create:** `lib/domain/usecases/user/get_user_league_status_usecase.dart`
- **Delete:** `lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart`
- **Delete:** `lib/domain/usecases/user/get_user_weekly_position_usecase.dart`

### Data Layer
- **Modify:** `lib/data/models/user/leaderboard_entry_model.dart` — add new fields to fromJson/toEntity
- **Create:** `lib/data/models/user/league_status_model.dart`
- **Modify:** `lib/data/repositories/supabase/supabase_user_repository.dart` — remove 4 weekly methods, add 2 new

### Presentation Layer
- **Modify:** `lib/presentation/providers/usecase_providers.dart` — remove 2 old, add 2 new
- **Modify:** `lib/presentation/providers/leaderboard_provider.dart` — add league status/group providers, update display state
- **Modify:** `lib/presentation/screens/leaderboard/leaderboard_screen.dart` — add "not joined" state, bot tap guard, school badge, pull-to-refresh

### Docs
- **Modify:** `docs/specs/12-leaderboard-leagues.md` — update to reflect new design

---

## Task 1: Database Migration — Tables and Helper Functions

**Files:**
- Create: `supabase/migrations/20260331000001_league_matchmaking_redesign.sql`

- [ ] **Step 1: Create the migration file with new tables**

```sql
-- =============================================
-- League Matchmaking Redesign
-- Part 1: New tables, helper functions, RLS
-- =============================================

-- 1a. bot_profiles (static seed data)
CREATE TABLE IF NOT EXISTS bot_profiles (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR NOT NULL,
    last_name VARCHAR NOT NULL,
    avatar_equipped_cache JSONB,
    school_name VARCHAR NOT NULL
);

-- 1b. league_groups
CREATE TABLE IF NOT EXISTS league_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    week_start DATE NOT NULL,
    tier VARCHAR(20) NOT NULL,
    xp_bucket INTEGER NOT NULL DEFAULT 0,
    member_count INTEGER NOT NULL DEFAULT 0,
    processed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_league_groups_week_tier_bucket ON league_groups(week_start, tier, xp_bucket);
CREATE INDEX idx_league_groups_unprocessed ON league_groups(week_start) WHERE processed = false;

-- 1c. league_group_members (real students only — bots are virtual)
CREATE TABLE IF NOT EXISTS league_group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES league_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    school_id UUID,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, week_start)
);

CREATE INDEX idx_league_group_members_user_week ON league_group_members(user_id, week_start);
CREATE INDEX idx_league_group_members_group ON league_group_members(group_id);
CREATE INDEX idx_league_group_members_group_user ON league_group_members(group_id, user_id);

-- 1d. RLS on new tables
ALTER TABLE league_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE league_group_members ENABLE ROW LEVEL SECURITY;

-- 1e. Add group_id to league_history + update result CHECK constraint
ALTER TABLE league_history ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES league_groups(id) ON DELETE SET NULL;

DO $$ BEGIN
  ALTER TABLE league_history DROP CONSTRAINT IF EXISTS league_history_result_check;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;
-- No CHECK constraint re-added — result column is free-form VARCHAR(20)

-- 1f. Bot XP helper functions
CREATE OR REPLACE FUNCTION bot_weekly_xp_target(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text));
    v_min INTEGER;
    v_max INTEGER;
BEGIN
    CASE p_xp_bucket
        WHEN 0 THEN v_min := 20;  v_max := 80;
        WHEN 1 THEN v_min := 30;  v_max := 99;
        WHEN 2 THEN v_min := 100; v_max := 299;
        WHEN 3 THEN v_min := 300; v_max := 599;
        WHEN 4 THEN v_min := 600; v_max := 1000;
        ELSE         v_min := 20;  v_max := 80;
    END CASE;
    RETURN v_min + (v_seed % (v_max - v_min + 1));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION bot_current_xp(
    p_group_id UUID,
    p_slot INTEGER,
    p_xp_bucket INTEGER,
    p_week_start DATE
) RETURNS INTEGER AS $$
DECLARE
    v_target INTEGER := bot_weekly_xp_target(p_group_id, p_slot, p_xp_bucket);
    v_elapsed FLOAT := EXTRACT(EPOCH FROM (app_now() - p_week_start::timestamptz)) / (7.0 * 86400);
    v_day_seed INTEGER := abs(hashtext(p_group_id::text || '_' || p_slot::text || '_' || EXTRACT(DOW FROM app_now())::text));
    v_jitter FLOAT := (v_day_seed % 20 - 10) / 100.0;
BEGIN
    v_elapsed := GREATEST(0, LEAST(1, v_elapsed));
    RETURN LEAST(v_target, GREATEST(0, (v_target * (v_elapsed + v_jitter))::INTEGER));
END;
$$ LANGUAGE plpgsql STABLE;
```

- [ ] **Step 2: Seed bot_profiles with ~200 entries**

Add to the same migration file. Generate diverse Turkish/international names and avatar configs:

```sql
-- 1g. Seed bot_profiles (~200 entries)
-- Using a representative sample here; full 200 entries in actual migration
INSERT INTO bot_profiles (first_name, last_name, avatar_equipped_cache, school_name) VALUES
('Emre', 'Yıldız', '{"base_url": "animals/fox.png", "layers": []}', 'Atatürk İlkokulu'),
('Zeynep', 'Kaya', '{"base_url": "animals/cat.png", "layers": []}', 'Cumhuriyet Ortaokulu'),
('Mehmet', 'Demir', '{"base_url": "animals/bear.png", "layers": []}', 'Fatih İlkokulu'),
('Elif', 'Çelik', '{"base_url": "animals/rabbit.png", "layers": []}', 'Mimar Sinan Ortaokulu'),
('Ahmet', 'Şahin', '{"base_url": "animals/owl.png", "layers": []}', 'İnönü İlkokulu'),
('Ayşe', 'Arslan', '{"base_url": "animals/penguin.png", "layers": []}', 'Kurtuluş Ortaokulu'),
('Can', 'Özdemir', '{"base_url": "animals/dog.png", "layers": []}', 'Barış İlkokulu'),
('Defne', 'Aydın', '{"base_url": "animals/panda.png", "layers": []}', 'Gazi Ortaokulu'),
('Burak', 'Koç', '{"base_url": "animals/lion.png", "layers": []}', 'Namık Kemal İlkokulu'),
('Selin', 'Yılmaz', '{"base_url": "animals/fox.png", "layers": []}', 'Atatürk Ortaokulu');
-- ... continue to ~200 entries with varied names, animals, and school names
-- Use the actual avatar base_url values from the avatar_items table in production
```

**Implementation note:** The full 200 entries should use actual `base_url` values from the existing `avatar_items` table. Query `SELECT DISTINCT image_url FROM avatar_items WHERE category = 'base'` to get valid base avatar URLs for the seed data.

- [ ] **Step 3: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the migration will be applied, no errors.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260331000001_league_matchmaking_redesign.sql
git commit -m "feat(db): add league matchmaking tables, bot_profiles, and helper functions"
```

---

## Task 2: Database Migration — join_weekly_league RPC

**Files:**
- Modify: `supabase/migrations/20260331000001_league_matchmaking_redesign.sql` (append)

- [ ] **Step 1: Add join_weekly_league RPC**

Append to the migration file:

```sql
-- =============================================
-- Part 2: join_weekly_league RPC
-- =============================================
CREATE OR REPLACE FUNCTION join_weekly_league(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_week_start DATE := date_trunc('week', app_now())::DATE;
    v_prev_week_start TIMESTAMPTZ := date_trunc('week', app_now()) - INTERVAL '7 days';
    v_prev_week_end TIMESTAMPTZ := date_trunc('week', app_now());
    v_tier VARCHAR(20);
    v_school_id UUID;
    v_last_week_xp BIGINT;
    v_bucket INTEGER;
    v_group_id UUID;
BEGIN
    -- Idempotency: already in a group this week?
    IF EXISTS (
        SELECT 1 FROM league_group_members
        WHERE user_id = p_user_id AND week_start = v_week_start
    ) THEN
        RETURN;
    END IF;

    -- Get user's tier and school
    SELECT league_tier, school_id INTO v_tier, v_school_id
    FROM profiles WHERE id = p_user_id;

    IF v_tier IS NULL THEN RETURN; END IF;

    -- Calculate XP bucket from last week
    SELECT COALESCE(SUM(amount), 0) INTO v_last_week_xp
    FROM xp_logs
    WHERE user_id = p_user_id
    AND created_at >= v_prev_week_start
    AND created_at < v_prev_week_end;

    v_bucket := CASE
        WHEN v_last_week_xp = 0 THEN 0
        WHEN v_last_week_xp < 100 THEN 1
        WHEN v_last_week_xp < 300 THEN 2
        WHEN v_last_week_xp < 600 THEN 3
        ELSE 4
    END;

    -- Priority a: same tier + same bucket + same school member
    SELECT lg.id INTO v_group_id
    FROM league_groups lg
    WHERE lg.week_start = v_week_start AND lg.tier = v_tier AND lg.xp_bucket = v_bucket
    AND lg.member_count < 30
    AND EXISTS (
        SELECT 1 FROM league_group_members lgm
        WHERE lgm.group_id = lg.id AND lgm.school_id = v_school_id
    )
    ORDER BY lg.member_count DESC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    -- Priority b: same tier + same bucket
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier AND lg.xp_bucket = v_bucket
        AND lg.member_count < 30
        ORDER BY lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority c: neighbor bucket + same school
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier
        AND lg.xp_bucket BETWEEN GREATEST(0, v_bucket - 1) AND LEAST(4, v_bucket + 1)
        AND lg.member_count < 30
        AND EXISTS (
            SELECT 1 FROM league_group_members lgm
            WHERE lgm.group_id = lg.id AND lgm.school_id = v_school_id
        )
        ORDER BY abs(lg.xp_bucket - v_bucket), lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority d: neighbor bucket
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier
        AND lg.xp_bucket BETWEEN GREATEST(0, v_bucket - 1) AND LEAST(4, v_bucket + 1)
        AND lg.member_count < 30
        ORDER BY abs(lg.xp_bucket - v_bucket), lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority e: any bucket in same tier
    IF v_group_id IS NULL THEN
        SELECT lg.id INTO v_group_id
        FROM league_groups lg
        WHERE lg.week_start = v_week_start AND lg.tier = v_tier
        AND lg.member_count < 30
        ORDER BY lg.member_count DESC
        LIMIT 1
        FOR UPDATE SKIP LOCKED;
    END IF;

    -- Priority f: create new group
    IF v_group_id IS NULL THEN
        INSERT INTO league_groups (week_start, tier, xp_bucket, member_count)
        VALUES (v_week_start, v_tier, v_bucket, 0)
        RETURNING id INTO v_group_id;
    END IF;

    -- Join the group
    INSERT INTO league_group_members (group_id, user_id, week_start, school_id)
    VALUES (v_group_id, p_user_id, v_week_start, v_school_id);

    UPDATE league_groups SET member_count = member_count + 1
    WHERE id = v_group_id;
END;
$$;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/20260331000001_league_matchmaking_redesign.sql
git commit -m "feat(db): add join_weekly_league matchmaking RPC"
```

---

## Task 3: Database Migration — Leaderboard and Status RPCs

**Files:**
- Modify: `supabase/migrations/20260331000001_league_matchmaking_redesign.sql` (append)

- [ ] **Step 1: Add get_league_group_leaderboard RPC**

Append to migration:

```sql
-- =============================================
-- Part 3: get_league_group_leaderboard RPC
-- =============================================
CREATE OR REPLACE FUNCTION get_league_group_leaderboard(
    p_group_id UUID,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR,
    school_name VARCHAR,
    is_same_school BOOLEAN,
    is_bot BOOLEAN,
    group_member_count INTEGER,
    previous_group_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_group RECORD;
    v_total_bots INTEGER;
    v_bot_count INTEGER;
    v_caller_school_id UUID;
    v_week_start_ts TIMESTAMPTZ;
    v_prev_week_start DATE;
BEGIN
    -- Auth check: caller must be a member of this group
    IF NOT EXISTS (
        SELECT 1 FROM league_group_members
        WHERE group_id = p_group_id AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: caller is not a member of this group';
    END IF;

    -- Fetch group info once (snapshot for consistent bot count within this call)
    SELECT * INTO v_group FROM league_groups WHERE id = p_group_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Group not found';
    END IF;

    v_total_bots := (SELECT count(*)::INTEGER FROM bot_profiles);
    v_bot_count := GREATEST(0, 30 - v_group.member_count);
    v_week_start_ts := v_group.week_start::timestamptz;
    v_prev_week_start := (v_group.week_start - INTERVAL '7 days')::DATE;

    SELECT school_id INTO v_caller_school_id FROM profiles WHERE id = auth.uid();

    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start_ts
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank,
            lh.group_id AS prev_group_id
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
    ),
    real_entries AS (
        SELECT
            p.id AS e_user_id,
            p.first_name AS e_first_name,
            p.last_name AS e_last_name,
            p.avatar_url AS e_avatar_url,
            p.avatar_equipped_cache AS e_avatar_equipped_cache,
            p.xp AS e_total_xp,
            COALESCE(wxc.week_xp, 0)::BIGINT AS e_weekly_xp,
            p.level AS e_level,
            pw.prev_rank AS e_previous_rank,
            pw.prev_group_id AS e_prev_group_id,
            p.league_tier AS e_league_tier,
            s.name AS e_school_name,
            (p.school_id = v_caller_school_id) AS e_is_same_school,
            FALSE AS e_is_bot
        FROM league_group_members lgm
        JOIN profiles p ON lgm.user_id = p.id
        LEFT JOIN schools s ON p.school_id = s.id
        LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
        LEFT JOIN prev_week pw ON p.id = pw.uid
        WHERE lgm.group_id = p_group_id
    ),
    bot_entries AS (
        SELECT
            ('00000000-0000-0000-0000-' || LPAD(bp.id::text, 12, '0'))::UUID AS e_user_id,
            bp.first_name AS e_first_name,
            bp.last_name AS e_last_name,
            NULL::VARCHAR AS e_avatar_url,
            bp.avatar_equipped_cache AS e_avatar_equipped_cache,
            0 AS e_total_xp,
            bot_current_xp(p_group_id, slot_num, v_group.xp_bucket, v_group.week_start)::BIGINT AS e_weekly_xp,
            GREATEST(1, bot_weekly_xp_target(p_group_id, slot_num, v_group.xp_bucket) / 50 + 1) AS e_level,
            NULL::INTEGER AS e_previous_rank,
            NULL::UUID AS e_prev_group_id,
            v_group.tier AS e_league_tier,
            bp.school_name AS e_school_name,
            FALSE AS e_is_same_school,
            TRUE AS e_is_bot
        FROM generate_series(0, v_bot_count - 1) AS slot_num
        JOIN bot_profiles bp ON bp.id = (abs(hashtext(p_group_id::text || '_slot_' || slot_num::text)) % v_total_bots) + 1
        WHERE v_bot_count > 0 AND v_total_bots > 0
    ),
    all_entries AS (
        SELECT * FROM real_entries
        UNION ALL
        SELECT * FROM bot_entries
    ),
    ranked AS (
        SELECT *, RANK() OVER (ORDER BY e_weekly_xp DESC, e_total_xp DESC) AS e_rank
        FROM all_entries
    )
    SELECT
        r.e_user_id, r.e_first_name, r.e_last_name, r.e_avatar_url,
        r.e_avatar_equipped_cache, r.e_total_xp::INTEGER, r.e_weekly_xp,
        r.e_level::INTEGER, r.e_rank, r.e_previous_rank,
        r.e_league_tier, r.e_school_name, r.e_is_same_school, r.e_is_bot,
        30::INTEGER,
        r.e_prev_group_id
    FROM ranked r
    ORDER BY r.e_rank
    LIMIT p_limit;
END;
$$;
```

- [ ] **Step 2: Add get_user_league_status RPC**

```sql
-- =============================================
-- Part 3b: get_user_league_status RPC
-- =============================================
CREATE OR REPLACE FUNCTION get_user_league_status(p_user_id UUID)
RETURNS TABLE(
    group_id UUID,
    group_member_count INTEGER,
    tier VARCHAR,
    week_start DATE,
    weekly_xp BIGINT,
    rank BIGINT,
    joined BOOLEAN,
    threshold_met BOOLEAN,
    current_weekly_xp BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_week_start DATE := date_trunc('week', app_now())::DATE;
    v_week_start_ts TIMESTAMPTZ := date_trunc('week', app_now());
    v_current_weekly_xp BIGINT;
    v_group_id UUID;
    v_user_tier VARCHAR(20);
    v_group_bucket INTEGER;
    v_group_member_count INTEGER;
    v_total_bots INTEGER;
    v_bot_count INTEGER;
    v_user_rank BIGINT;
BEGIN
    -- Auth check
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Access denied: user mismatch';
    END IF;

    -- Get current weekly XP
    SELECT COALESCE(SUM(amount), 0) INTO v_current_weekly_xp
    FROM xp_logs
    WHERE user_id = p_user_id AND created_at >= v_week_start_ts;

    -- Get user's tier
    SELECT league_tier INTO v_user_tier FROM profiles WHERE id = p_user_id;

    -- Check if in a group
    SELECT lgm.group_id INTO v_group_id
    FROM league_group_members lgm
    WHERE lgm.user_id = p_user_id AND lgm.week_start = v_week_start;

    IF v_group_id IS NULL THEN
        -- Not joined
        RETURN QUERY SELECT
            NULL::UUID, NULL::INTEGER, v_user_tier, v_week_start,
            v_current_weekly_xp, NULL::BIGINT,
            FALSE, (v_current_weekly_xp >= 20),
            v_current_weekly_xp;
        RETURN;
    END IF;

    -- Get group info for bot generation
    SELECT lg.xp_bucket, lg.member_count INTO v_group_bucket, v_group_member_count
    FROM league_groups lg WHERE lg.id = v_group_id;

    v_total_bots := (SELECT count(*)::INTEGER FROM bot_profiles);
    v_bot_count := GREATEST(0, 30 - v_group_member_count);

    -- Compute rank using same bot-merge pattern as leaderboard (inlined, not called)
    SELECT ranked.rnk INTO v_user_rank
    FROM (
        WITH weekly_xp_calc AS (
            SELECT xl.user_id AS uid, COALESCE(SUM(xl.amount), 0) AS week_xp
            FROM xp_logs xl WHERE xl.created_at >= v_week_start_ts GROUP BY xl.user_id
        ),
        real_entries AS (
            SELECT p.id AS eid, COALESCE(wxc.week_xp, 0)::BIGINT AS ewxp, p.xp AS etxp
            FROM league_group_members lgm
            JOIN profiles p ON lgm.user_id = p.id
            LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
            WHERE lgm.group_id = v_group_id
        ),
        bot_entries AS (
            SELECT
                ('00000000-0000-0000-0000-' || LPAD(bp.id::text, 12, '0'))::UUID AS eid,
                bot_current_xp(v_group_id, slot_num, v_group_bucket, v_week_start)::BIGINT AS ewxp,
                0::INTEGER AS etxp
            FROM generate_series(0, v_bot_count - 1) AS slot_num
            JOIN bot_profiles bp ON bp.id = (abs(hashtext(v_group_id::text || '_slot_' || slot_num::text)) % v_total_bots) + 1
            WHERE v_bot_count > 0 AND v_total_bots > 0
        ),
        all_entries AS (SELECT * FROM real_entries UNION ALL SELECT * FROM bot_entries),
        ranked_all AS (
            SELECT eid, RANK() OVER (ORDER BY ewxp DESC, etxp DESC) AS rnk FROM all_entries
        )
        SELECT * FROM ranked_all
    ) ranked
    WHERE ranked.eid = p_user_id;

    RETURN QUERY SELECT
        v_group_id, 30::INTEGER, v_user_tier, v_week_start,
        v_current_weekly_xp, v_user_rank,
        TRUE, TRUE, v_current_weekly_xp;
END;
$$;
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260331000001_league_matchmaking_redesign.sql
git commit -m "feat(db): add league group leaderboard and status RPCs"
```

---

## Task 4: Database Migration — Reset Rewrite, XP Trigger, Cleanup

**Files:**
- Modify: `supabase/migrations/20260331000001_league_matchmaking_redesign.sql` (append)

- [ ] **Step 1: Rewrite process_weekly_league_reset**

```sql
-- =============================================
-- Part 4: Rewrite process_weekly_league_reset
-- =============================================
CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
    v_last_week_ts TIMESTAMPTZ := date_trunc('week', app_now()) - INTERVAL '7 days';
    v_this_week_ts TIMESTAMPTZ := date_trunc('week', app_now());
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
    -- Pre-aggregate weekly XP for the last week
    CREATE TEMP TABLE IF NOT EXISTS tmp_weekly_xp AS
    SELECT xl.user_id, COALESCE(SUM(xl.amount), 0)::BIGINT AS week_xp
    FROM xp_logs xl
    WHERE xl.created_at >= v_last_week_ts AND xl.created_at < v_this_week_ts
    GROUP BY xl.user_id;
    CREATE INDEX IF NOT EXISTS idx_tmp_wx_user ON tmp_weekly_xp(user_id);

    -- Process each unprocessed group from last week
    FOR v_group IN
        SELECT * FROM league_groups
        WHERE week_start = v_last_week_start AND processed = false
        FOR UPDATE
    LOOP
        v_bot_count := GREATEST(0, 30 - v_group.member_count);

        -- Zone size: with virtual bots, display count is always 30 → zone = 5
        -- (bots fill empty slots, so total ranked entries = real + bots = 30)
        v_zone_size := 5;

        -- Rank real + bot entries together
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
            -- Skip bots entirely
            IF v_entry.entry_is_bot THEN CONTINUE; END IF;

            v_result := 'stayed';
            v_new_tier := v_entry.entry_tier;
            v_tier_idx := array_position(v_tier_order, v_entry.entry_tier);

            -- Promotion zone
            IF v_zone_size > 0 AND v_entry.entry_rank <= v_zone_size AND v_tier_idx < 5 THEN
                v_new_tier := v_tier_order[v_tier_idx + 1];
                v_result := 'promoted';
            -- Demotion zone
            ELSIF v_zone_size > 0 AND v_entry.entry_rank > (v_group.member_count + v_bot_count - v_zone_size) AND v_tier_idx > 1 THEN
                v_new_tier := v_tier_order[v_tier_idx - 1];
                v_result := 'demoted';
            END IF;

            INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result, group_id)
            VALUES (v_entry.entry_id, v_entry.entry_class_id, v_entry.entry_school_id,
                    v_last_week_start, v_new_tier, v_entry.entry_rank, v_entry.entry_weekly_xp, v_result, v_group.id);

            IF v_new_tier != v_entry.entry_tier THEN
                UPDATE profiles SET league_tier = v_new_tier WHERE id = v_entry.entry_id;
            END IF;
        END LOOP;

        UPDATE league_groups SET processed = true WHERE id = v_group.id;
    END LOOP;

    -- Inactive tier decay: 4+ weeks without joining a group
    -- IMPORTANT: Insert history FIRST (captures pre-decay tier), THEN update profiles
    INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
    SELECT p.id, p.class_id, p.school_id, v_last_week_start,
           -- Store the NEW (demoted) tier in league_history, consistent with promotion/demotion pattern
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
        AND lgm.week_start >= (date_trunc('week', app_now()) - INTERVAL '28 days')::DATE
    )
    AND NOT EXISTS (
        SELECT 1 FROM league_history lh
        WHERE lh.user_id = p.id AND lh.week_start = v_last_week_start
    );

    -- THEN update profiles (after history is captured)
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
        AND lgm.week_start >= (date_trunc('week', app_now()) - INTERVAL '28 days')::DATE
    );

    -- Cleanup old groups (> 8 weeks)
    DELETE FROM league_groups
    WHERE week_start < (date_trunc('week', app_now()) - INTERVAL '8 weeks')::DATE;

    DROP TABLE IF EXISTS tmp_weekly_xp;
END;
$$;
```

- [ ] **Step 2: Modify award_xp_transaction to trigger lazy join**

```sql
-- =============================================
-- Part 4b: Add lazy join trigger to award_xp_transaction
-- =============================================
CREATE OR REPLACE FUNCTION award_xp_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_xp INTEGER, new_level INTEGER, level_up BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_xp INTEGER;
    v_current_coins INTEGER;
    v_new_xp INTEGER;
    v_new_coins INTEGER;
    v_current_level INTEGER;
    v_new_level INTEGER;
    v_weekly_xp BIGINT;
BEGIN
    -- Auth check: ensure caller is the user they claim to be
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Not authorized: user mismatch';
    END IF;

    -- Lock the row FIRST to prevent race conditions
    SELECT xp, level, coins INTO v_current_xp, v_current_level, v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Idempotency check AFTER lock (prevents TOCTOU race condition)
    IF p_source_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM xp_logs
        WHERE user_id = p_user_id AND source = p_source AND source_id = p_source_id
    ) THEN
        RETURN QUERY SELECT v_current_xp, v_current_level, false;
        RETURN;
    END IF;

    -- Calculate new values
    v_new_xp := v_current_xp + p_amount;
    v_new_level := calculate_level(v_new_xp);
    v_new_coins := v_current_coins + p_amount;

    -- Update profile (XP + level + coins atomically)
    UPDATE profiles
    SET xp = v_new_xp,
        level = v_new_level,
        coins = v_new_coins,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Log XP
    INSERT INTO xp_logs (user_id, amount, source, source_id, description)
    VALUES (p_user_id, p_amount, p_source, p_source_id, p_description);

    -- Log coins
    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, p_amount, v_new_coins, p_source, p_source_id, p_description);

    -- === NEW: Lazy join to weekly league ===
    IF NOT EXISTS (
        SELECT 1 FROM league_group_members
        WHERE user_id = p_user_id
        AND week_start = date_trunc('week', app_now())::DATE
    ) THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_weekly_xp
        FROM xp_logs
        WHERE user_id = p_user_id
        AND created_at >= date_trunc('week', app_now());

        IF v_weekly_xp >= 20 THEN
            PERFORM join_weekly_league(p_user_id);
        END IF;
    END IF;

    RETURN QUERY SELECT v_new_xp, v_new_level, (v_new_level > v_current_level);
END;
$$;
```

- [ ] **Step 3: Drop old weekly RPCs**

```sql
-- =============================================
-- Part 4c: Drop old weekly RPCs
-- =============================================
DROP FUNCTION IF EXISTS get_weekly_class_leaderboard(UUID, INTEGER);
DROP FUNCTION IF EXISTS get_weekly_school_leaderboard(UUID, INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS get_user_weekly_class_position(UUID, UUID);
DROP FUNCTION IF EXISTS get_user_weekly_school_position(UUID, UUID, VARCHAR);
```

- [ ] **Step 4: Dry-run full migration**

Run: `supabase db push --dry-run`
Expected: Full migration preview with no errors.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260331000001_league_matchmaking_redesign.sql
git commit -m "feat(db): rewrite league reset, add lazy join trigger, drop old RPCs"
```

---

## Task 5: Push Migration to Supabase

- [ ] **Step 1: Push the migration**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 2: Verify new tables exist**

Run: `supabase db push --dry-run`
Expected: "No pending migrations" (nothing to apply).

- [ ] **Step 3: Commit** (no code change — just confirming migration is live)

---

## Task 6: Shared Package Updates

**Files:**
- Modify: `packages/owlio_shared/lib/src/constants/league_constants.dart`
- Modify: `packages/owlio_shared/lib/src/constants/rpc_functions.dart`

- [ ] **Step 1: Update leagueZoneSize**

In `packages/owlio_shared/lib/src/constants/league_constants.dart`, replace the entire function:

```dart
/// Zone size for league promotion/demotion.
///
/// With virtual bots, display size is always 30 (zone size = 5).
/// This table handles edge cases where real member count is used directly.
/// Must match the thresholds in process_weekly_league_reset() SQL function.
int leagueZoneSize(int groupSize) {
  if (groupSize < 5) return 0;
  if (groupSize < 10) return 1;
  if (groupSize < 15) return 2;
  if (groupSize < 25) return 3;
  return 5;
}
```

- [ ] **Step 2: Update RPC constants**

In `packages/owlio_shared/lib/src/constants/rpc_functions.dart`, remove the old weekly constants and add new ones:

Remove these lines:
```dart
static const getWeeklyClassLeaderboard = 'get_weekly_class_leaderboard';
static const getWeeklySchoolLeaderboard = 'get_weekly_school_leaderboard';
static const getUserWeeklyClassPosition = 'get_user_weekly_class_position';
static const getUserWeeklySchoolPosition = 'get_user_weekly_school_position';
```

Add these lines (note: `joinWeeklyLeague` is NOT needed — it's called internally by `award_xp_transaction`, never from Dart):
```dart
static const getLeagueGroupLeaderboard = 'get_league_group_leaderboard';
static const getUserLeagueStatus = 'get_user_league_status';
```

- [ ] **Step 3: Verify no compile errors**

Run: `cd packages/owlio_shared && dart analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/league_constants.dart packages/owlio_shared/lib/src/constants/rpc_functions.dart
git commit -m "feat(shared): update league zone sizes and RPC constants for matchmaking"
```

---

## Task 7: Domain Layer — Entities and Repository Interface

**Files:**
- Modify: `lib/domain/entities/leaderboard_entry.dart`
- Create: `lib/domain/entities/league_status.dart`
- Modify: `lib/domain/repositories/user_repository.dart`

- [ ] **Step 1: Update LeaderboardEntry entity**

Add new fields to the constructor, class body, and props:

```dart
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.avatarEquippedCache,
    required this.totalXp,
    required this.weeklyXp,
    required this.level,
    required this.rank,
    this.previousRank,
    this.className,
    required this.leagueTier,
    this.totalCount,
    this.schoolName,
    this.isSameSchool = false,
    this.isBot = false,
    this.previousGroupId,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final Map<String, dynamic>? avatarEquippedCache;
  final int totalXp;
  final int weeklyXp;
  final int level;
  final int rank;
  final int? previousRank;
  final String? className;
  final LeagueTier leagueTier;
  final int? totalCount;
  final String? schoolName;
  final bool isSameSchool;
  final bool isBot;
  final String? previousGroupId;

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  int? get rankChange {
    if (previousRank == null) return null;
    return previousRank! - rank;
  }

  @override
  List<Object?> get props => [
        userId, firstName, lastName, avatarUrl, avatarEquippedCache,
        totalXp, weeklyXp, level, rank, previousRank, className,
        leagueTier, totalCount, schoolName, isSameSchool, isBot, groupId,
      ];
}
```

- [ ] **Step 2: Create LeagueStatus entity**

Create `lib/domain/entities/league_status.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

class LeagueStatus extends Equatable {
  const LeagueStatus({
    required this.joined,
    required this.thresholdMet,
    required this.currentWeeklyXp,
    this.previousGroupId,
    this.groupMemberCount,
    required this.tier,
    required this.weekStart,
    this.rank,
  });

  final bool joined;
  final bool thresholdMet;
  final int currentWeeklyXp;
  final String? previousGroupId;
  final int? groupMemberCount;
  final LeagueTier tier;
  final DateTime weekStart;
  final int? rank;

  @override
  List<Object?> get props => [
        joined, thresholdMet, currentWeeklyXp, groupId,
        groupMemberCount, tier, weekStart, rank,
      ];
}
```

- [ ] **Step 3: Update UserRepository interface**

In `lib/domain/repositories/user_repository.dart`, remove the 4 weekly methods and add 2 new ones:

Remove:
```dart
Future<Either<Failure, List<LeaderboardEntry>>> getWeeklyClassLeaderboard({...});
Future<Either<Failure, List<LeaderboardEntry>>> getWeeklySchoolLeaderboard({...});
Future<Either<Failure, LeaderboardEntry>> getUserWeeklyClassPosition({...});
Future<Either<Failure, LeaderboardEntry>> getUserWeeklySchoolPosition({...});
```

Add:
```dart
Future<Either<Failure, List<LeaderboardEntry>>> getLeagueGroupLeaderboard({
  required String groupId,
  int limit = 30,
});

Future<Either<Failure, LeagueStatus>> getUserLeagueStatus({
  required String userId,
});
```

Add import: `import '../entities/league_status.dart';`

- [ ] **Step 4: Verify compile**

Run: `dart analyze lib/domain/`
Expected: Errors in use cases and repository implementation (expected — we'll fix those next).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/leaderboard_entry.dart lib/domain/entities/league_status.dart lib/domain/repositories/user_repository.dart
git commit -m "feat(domain): update entities and repository interface for league matchmaking"
```

---

## Task 8: Domain Layer — Use Cases

**Files:**
- Create: `lib/domain/usecases/user/get_league_group_leaderboard_usecase.dart`
- Create: `lib/domain/usecases/user/get_user_league_status_usecase.dart`
- Delete: `lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart`
- Delete: `lib/domain/usecases/user/get_user_weekly_position_usecase.dart`

- [ ] **Step 1: Create GetLeagueGroupLeaderboardUseCase**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/leaderboard_entry.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetLeagueGroupLeaderboardParams {
  const GetLeagueGroupLeaderboardParams({
    required this.groupId,
    this.limit = 30,
  });

  final String groupId;
  final int limit;
}

class GetLeagueGroupLeaderboardUseCase
    implements UseCase<List<LeaderboardEntry>, GetLeagueGroupLeaderboardParams> {
  const GetLeagueGroupLeaderboardUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> call(
    GetLeagueGroupLeaderboardParams params,
  ) {
    return _repository.getLeagueGroupLeaderboard(
      groupId: params.groupId,
      limit: params.limit,
    );
  }
}
```

- [ ] **Step 2: Create GetUserLeagueStatusUseCase**

```dart
import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/league_status.dart';
import '../../repositories/user_repository.dart';
import '../usecase.dart';

class GetUserLeagueStatusParams {
  const GetUserLeagueStatusParams({required this.userId});
  final String userId;
}

class GetUserLeagueStatusUseCase
    implements UseCase<LeagueStatus, GetUserLeagueStatusParams> {
  const GetUserLeagueStatusUseCase(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, LeagueStatus>> call(
    GetUserLeagueStatusParams params,
  ) {
    return _repository.getUserLeagueStatus(userId: params.userId);
  }
}
```

- [ ] **Step 3: Delete old use cases**

```bash
rm lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart
rm lib/domain/usecases/user/get_user_weekly_position_usecase.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/domain/usecases/user/
git commit -m "feat(domain): add league group leaderboard and status use cases, remove old weekly use cases"
```

---

## Task 9: Data Layer — Models and Repository Implementation

**Files:**
- Modify: `lib/data/models/user/leaderboard_entry_model.dart`
- Create: `lib/data/models/user/league_status_model.dart`
- Modify: `lib/data/repositories/supabase/supabase_user_repository.dart`

- [ ] **Step 1: Update LeaderboardEntryModel**

Update `fromJson` and `toEntity` to include new fields:

```dart
factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
  return LeaderboardEntryModel(
    userId: json['user_id'] as String,
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    avatarEquippedCache: json['avatar_equipped_cache'] as Map<String, dynamic>?,
    totalXp: (json['total_xp'] ?? json['xp']) as int? ?? 0,
    weeklyXp: (json['weekly_xp'] as num?)?.toInt() ?? 0,
    level: json['level'] as int? ?? 1,
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    previousRank: (json['previous_rank'] as num?)?.toInt(),
    className: json['class_name'] as String?,
    leagueTier: LeagueTier.fromDbValue(json['league_tier'] as String? ?? 'bronze'),
    totalCount: (json['total_count'] as num?)?.toInt(),
    schoolName: json['school_name'] as String?,
    isSameSchool: json['is_same_school'] as bool? ?? false,
    isBot: json['is_bot'] as bool? ?? false,
    previousGroupId: json['previous_group_id'] as String?,
  );
}
```

Add new fields to the class and `toEntity()`:
```dart
final String? schoolName;
final bool isSameSchool;
final bool isBot;
final String? groupId;

LeaderboardEntry toEntity() {
  return LeaderboardEntry(
    userId: userId,
    firstName: firstName,
    lastName: lastName,
    avatarUrl: avatarUrl,
    avatarEquippedCache: avatarEquippedCache,
    totalXp: totalXp,
    weeklyXp: weeklyXp,
    level: level,
    rank: rank,
    previousRank: previousRank,
    className: className,
    leagueTier: leagueTier,
    totalCount: totalCount,
    schoolName: schoolName,
    isSameSchool: isSameSchool,
    isBot: isBot,
    groupId: groupId,
  );
}
```

- [ ] **Step 2: Create LeagueStatusModel**

Create `lib/data/models/user/league_status_model.dart`:

```dart
import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/league_status.dart';

class LeagueStatusModel {
  const LeagueStatusModel({
    this.previousGroupId,
    this.groupMemberCount,
    required this.tier,
    required this.weekStart,
    this.weeklyXp = 0,
    this.rank,
    required this.joined,
    required this.thresholdMet,
    required this.currentWeeklyXp,
  });

  factory LeagueStatusModel.fromJson(Map<String, dynamic> json) {
    return LeagueStatusModel(
      groupId: json['group_id'] as String?,
      groupMemberCount: (json['group_member_count'] as num?)?.toInt(),
      tier: LeagueTier.fromDbValue(json['tier'] as String? ?? 'bronze'),
      weekStart: DateTime.parse(json['week_start'] as String),
      weeklyXp: (json['weekly_xp'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
      joined: json['joined'] as bool? ?? false,
      thresholdMet: json['threshold_met'] as bool? ?? false,
      currentWeeklyXp: (json['current_weekly_xp'] as num?)?.toInt() ?? 0,
    );
  }

  final String? previousGroupId;
  final int? groupMemberCount;
  final LeagueTier tier;
  final DateTime weekStart;
  final int weeklyXp;
  final int? rank;
  final bool joined;
  final bool thresholdMet;
  final int currentWeeklyXp;

  LeagueStatus toEntity() {
    return LeagueStatus(
      groupId: groupId,
      groupMemberCount: groupMemberCount,
      tier: tier,
      weekStart: weekStart,
      rank: rank,
      joined: joined,
      thresholdMet: thresholdMet,
      currentWeeklyXp: currentWeeklyXp,
    );
  }
}
```

- [ ] **Step 3: Update SupabaseUserRepository**

Remove the 4 weekly methods (lines 409-533) and add 2 new methods:

```dart
@override
Future<Either<Failure, List<LeaderboardEntry>>> getLeagueGroupLeaderboard({
  required String groupId,
  int limit = 30,
}) async {
  try {
    final result = await _supabase.rpc(
      RpcFunctions.getLeagueGroupLeaderboard,
      params: {'p_group_id': groupId, 'p_limit': limit},
    );

    final data = result as List?;
    if (data == null || data.isEmpty) return const Right([]);

    return Right(data
        .map((json) =>
            LeaderboardEntryModel.fromJson(json as Map<String, dynamic>)
                .toEntity())
        .toList());
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}

@override
Future<Either<Failure, LeagueStatus>> getUserLeagueStatus({
  required String userId,
}) async {
  try {
    final result = await _supabase.rpc(
      RpcFunctions.getUserLeagueStatus,
      params: {'p_user_id': userId},
    );

    if (result == null || (result as List).isEmpty) {
      // Return default "not joined" status rather than an error
      return Right(LeagueStatus(
        joined: false,
        thresholdMet: false,
        currentWeeklyXp: 0,
        tier: LeagueTier.bronze,
        weekStart: DateTime.now(),
      ));
    }

    return Right(
      LeagueStatusModel.fromJson(result[0] as Map<String, dynamic>)
          .toEntity(),
    );
  } on PostgrestException catch (e) {
    return Left(ServerFailure(e.message, code: e.code));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
```

Add imports:
```dart
import '../../../data/models/user/league_status_model.dart';
import '../../../domain/entities/league_status.dart';
```

- [ ] **Step 4: Verify compile**

Run: `dart analyze lib/data/ lib/domain/`
Expected: Errors only in presentation layer (providers still reference old use cases).

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/user/ lib/data/repositories/supabase/supabase_user_repository.dart
git commit -m "feat(data): add league status model, update leaderboard model, update repository"
```

---

## Task 10: Presentation Layer — Providers

**Files:**
- Modify: `lib/presentation/providers/usecase_providers.dart`
- Modify: `lib/presentation/providers/leaderboard_provider.dart`

- [ ] **Step 1: Update usecase_providers.dart**

Remove old weekly providers and add new ones:

Remove:
```dart
final getWeeklyLeaderboardUseCaseProvider = Provider((ref) {
  return GetWeeklyLeaderboardUseCase(ref.watch(userRepositoryProvider));
});

final getUserWeeklyPositionUseCaseProvider = Provider((ref) {
  return GetUserWeeklyPositionUseCase(ref.watch(userRepositoryProvider));
});
```

Add:
```dart
final getLeagueGroupLeaderboardUseCaseProvider = Provider((ref) {
  return GetLeagueGroupLeaderboardUseCase(ref.watch(userRepositoryProvider));
});

final getUserLeagueStatusUseCaseProvider = Provider((ref) {
  return GetUserLeagueStatusUseCase(ref.watch(userRepositoryProvider));
});
```

Update imports accordingly.

- [ ] **Step 2: Rewrite leaderboard_provider.dart**

Replace the entire file with the new provider structure:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/league_status.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/user/get_league_group_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_total_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_league_status_usecase.dart';
import '../../domain/usecases/user/get_user_total_position_usecase.dart';
import 'auth_provider.dart';
import 'usecase_providers.dart';

enum LeaderboardScope { classScope, schoolScope, leagueScope }

final leaderboardScopeProvider = StateProvider<LeaderboardScope>(
  (ref) => LeaderboardScope.leagueScope,
);

/// League status for the current user (joined?, group_id, progress).
final leagueStatusProvider =
    FutureProvider.autoDispose<LeagueStatus?>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return null;

  final useCase = ref.watch(getUserLeagueStatusUseCaseProvider);
  final result = await useCase(
    GetUserLeagueStatusParams(userId: currentUser.id),
  );
  return result.fold((_) => null, (status) => status);
});

/// League group leaderboard entries (30 entries = real + bots).
final leagueGroupEntriesProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final status = await ref.watch(leagueStatusProvider.future);
  if (status == null || !status.joined || status.groupId == null) return [];

  final useCase = ref.watch(getLeagueGroupLeaderboardUseCaseProvider);
  final result = await useCase(
    GetLeagueGroupLeaderboardParams(groupId: status.groupId!),
  );
  return result.fold((_) => [], (entries) => entries);
});

/// Total XP leaderboard entries (class/school scope only).
final totalLeaderboardEntriesProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return [];

  final scope = ref.watch(leaderboardScopeProvider);
  // League scope uses leagueGroupEntriesProvider, not this provider
  if (scope == LeaderboardScope.leagueScope) return [];

  final useCase = ref.watch(getTotalLeaderboardUseCaseProvider);

  if (scope == LeaderboardScope.classScope) {
    if (currentUser.classId == null) return [];
    final result = await useCase(GetTotalLeaderboardParams(
      scope: TotalLeaderboardScope.classScope,
      classId: currentUser.classId,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
  } else {
    final result = await useCase(GetTotalLeaderboardParams(
      scope: TotalLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
  }
});

/// Current user's total position (for class/school when outside top N).
final currentUserTotalPositionProvider =
    FutureProvider.autoDispose<LeaderboardEntry?>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return null;

  final scope = ref.watch(leaderboardScopeProvider);
  if (scope == LeaderboardScope.leagueScope) return null;

  final useCase = ref.watch(getUserTotalPositionUseCaseProvider);

  if (scope == LeaderboardScope.classScope) {
    if (currentUser.classId == null) return null;
    final result = await useCase(GetUserTotalPositionParams(
      userId: currentUser.id,
      scope: TotalLeaderboardScope.classScope,
      classId: currentUser.classId,
    ));
    return result.fold((_) => null, (entry) => entry);
  } else {
    final result = await useCase(GetUserTotalPositionParams(
      userId: currentUser.id,
      scope: TotalLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
    ));
    return result.fold((_) => null, (entry) => entry);
  }
});

/// Combined leaderboard display state.
final leaderboardDisplayProvider =
    FutureProvider.autoDispose<LeaderboardDisplayState>((ref) async {
  final scope = ref.watch(leaderboardScopeProvider);
  final currentUser = await ref.watch(currentUserProvider.future);

  if (currentUser == null) {
    return const LeaderboardDisplayState(
      entries: [],
      currentUserEntry: null,
      currentUserId: '',
    );
  }

  if (scope == LeaderboardScope.leagueScope) {
    final status = await ref.watch(leagueStatusProvider.future);
    final entries = await ref.watch(leagueGroupEntriesProvider.future);

    return LeaderboardDisplayState(
      entries: entries,
      currentUserEntry: null,
      currentUserId: currentUser.id,
      scope: scope,
      leagueStatus: status,
    );
  }

  // Class/School scope — same as before
  final entries = await ref.watch(totalLeaderboardEntriesProvider.future);
  final userPosition = await ref.watch(currentUserTotalPositionProvider.future);
  final isInList = entries.any((e) => e.userId == currentUser.id);

  return LeaderboardDisplayState(
    entries: entries,
    currentUserEntry: isInList ? null : userPosition,
    currentUserId: currentUser.id,
    scope: scope,
  );
});

/// State class for leaderboard display.
class LeaderboardDisplayState {
  const LeaderboardDisplayState({
    required this.entries,
    required this.currentUserEntry,
    required this.currentUserId,
    this.scope = LeaderboardScope.classScope,
    this.leagueStatus,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;
  final String currentUserId;
  final LeaderboardScope scope;
  final LeagueStatus? leagueStatus;

  bool get isLeagueMode => scope == LeaderboardScope.leagueScope;
  bool get isEmpty => entries.isEmpty;
  bool isCurrentUser(String userId) => userId == currentUserId;

  /// Whether user has joined a league group this week.
  bool get isLeagueJoined => leagueStatus?.joined ?? false;

  /// Total display count (always 30 for league, entries.length + user for others).
  int get totalCount => isLeagueMode ? 30 : entries.length + (currentUserEntry != null ? 1 : 0);
}
```

- [ ] **Step 3: Verify compile**

Run: `dart analyze lib/presentation/providers/`
Expected: No errors in providers. May still have errors in screen (next task).

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/usecase_providers.dart lib/presentation/providers/leaderboard_provider.dart
git commit -m "feat(providers): add league status and group providers, remove old weekly providers"
```

---

## Task 11: Presentation Layer — LeaderboardScreen Update

**Files:**
- Modify: `lib/presentation/screens/leaderboard/leaderboard_screen.dart`

- [ ] **Step 1: Update the screen**

Key changes to `leaderboard_screen.dart`:

1. **Rename provider references:** `leaderboardEntriesProvider` → `totalLeaderboardEntriesProvider`, `currentUserPositionProvider` → `currentUserTotalPositionProvider` throughout the file.

2. **Add "Not Joined" state** — in `build()`, when `scope == leagueScope && !state.isLeagueJoined`:
```dart
if (scope == LeaderboardScope.leagueScope && !state.isLeagueJoined) {
  return _NotJoinedCard(status: state.leagueStatus);
}
```
Create `_NotJoinedCard` widget with progress bar:
```dart
class _NotJoinedCard extends StatelessWidget {
  const _NotJoinedCard({this.status});
  final LeagueStatus? status;

  @override
  Widget build(BuildContext context) {
    final xp = status?.currentWeeklyXp ?? 0;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.neutral, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.waspDark),
            const SizedBox(height: 16),
            Text('Join this week\'s league!',
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Earn 20 XP to start competing.',
              style: GoogleFonts.nunito(color: AppColors.neutralText, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: xp / 20, minHeight: 8,
              backgroundColor: AppColors.neutral, color: AppColors.waspDark),
            const SizedBox(height: 8),
            Text('$xp / 20 XP', style: GoogleFonts.nunito(fontWeight: FontWeight.w800,
              color: AppColors.waspDark)),
          ],
        ),
      ),
    );
  }
}
```

3. **Bot tap guard** — in `_buildEntryCard` and `_PodiumEntry`:
```dart
// In _buildEntryCard:
GestureDetector(
  onTap: entry.isBot ? null : () => showStudentProfileDialog(context, entry),
  // ...
)

// In _PodiumEntry:
GestureDetector(
  onTap: entry.isBot ? null : onTap,
  // ...
)
```

4. **Same-school badge** — in `_buildEntryCard`, after the name column:
```dart
if (state.isLeagueMode && entry.isSameSchool && !entry.isBot) ...[
  const Icon(Icons.school_rounded, size: 14, color: AppColors.secondary),
  const SizedBox(width: 4),
],
```

5. **Rank change suppression** — in `_RankChangeIndicator` or where it's used:
```dart
// Suppress rank change for bots and cross-group comparisons
final effectiveRankChange = entry.isBot
    ? null
    : (state.leagueStatus?.groupId != null &&
       entry.previousGroupId != null &&
       entry.previousGroupId != state.leagueStatus!.groupId)
        ? null  // different group → suppress
        : entry.rankChange;
```

6. **Zone size** — in `_ZonePreviewBanner` and `_buildEntryCard`:
```dart
// Replace: final totalEntries = state.leagueTotalCount ?? state.totalCount;
final totalEntries = state.totalCount; // always 30 in league mode
final zoneSize = leagueZoneSize(totalEntries);
```

7. **Pull-to-refresh** — wrap the `Expanded` content area:
```dart
Expanded(
  child: RefreshIndicator(
    onRefresh: () async {
      ref.invalidate(leaderboardDisplayProvider);
      if (scope == LeaderboardScope.leagueScope) {
        ref.invalidate(leagueStatusProvider);
        ref.invalidate(leagueGroupEntriesProvider);
      }
    },
    child: displayAsync.when(/* ... existing content ... */),
  ),
),
```

Implement these changes one by one, verifying compile after each.

- [ ] **Step 2: Verify full compile**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/leaderboard/leaderboard_screen.dart
git commit -m "feat(ui): update leaderboard screen with league matchmaking, bot guards, and join state"
```

---

## Task 12: Update Spec 12 and Final Verification

**Files:**
- Modify: `docs/specs/12-leaderboard-leagues.md`

- [ ] **Step 1: Update spec 12**

Add a note at the top of `docs/specs/12-leaderboard-leagues.md`:

```markdown
> **SUPERSEDED:** This spec has been redesigned. See `docs/superpowers/specs/2026-03-31-league-matchmaking-redesign.md` for the current design with cross-school matchmaking, virtual bots, and lazy join.
```

Update the Key Files, RPC Functions, Data Model, and Business Rules sections to reflect the new system.

- [ ] **Step 2: Run full analysis**

Run: `dart analyze lib/`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add docs/specs/12-leaderboard-leagues.md
git commit -m "docs: update spec 12 to reference league matchmaking redesign"
```

---

## Task Summary

| Task | Description | Estimated Steps |
|------|-------------|-----------------|
| 1 | DB: Tables, bot_profiles seed, helper functions | 4 |
| 2 | DB: join_weekly_league RPC | 2 |
| 3 | DB: Leaderboard and status RPCs | 3 |
| 4 | DB: Reset rewrite, XP trigger, old RPC drop | 5 |
| 5 | Push migration to Supabase | 3 |
| 6 | Shared package: zone sizes + RPC constants | 4 |
| 7 | Domain: entities + repository interface | 5 |
| 8 | Domain: use cases (create new, delete old) | 4 |
| 9 | Data: models + repository implementation | 5 |
| 10 | Presentation: providers | 4 |
| 11 | Presentation: leaderboard screen | 3 |
| 12 | Update spec 12 + final verification | 3 |
