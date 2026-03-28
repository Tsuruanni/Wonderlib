# Leaderboard/Leagues Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 8 audit findings (3 medium, 5 low) from the Feature #12 leaderboard/leagues audit.

**Architecture:** Database migration fixes the league reset regression (tier-based algorithm), adds auth checks to 8 RPCs, returns `total_count` for accurate zone banners, and drops stale RLS. Dart-side changes consolidate duplicate enums, add type-safe `LeagueTier` params, propagate `totalCount` to UI, and add shared zone-size constants.

**Tech Stack:** PostgreSQL (Supabase migrations), Dart/Flutter (Riverpod), owlio_shared package

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `supabase/migrations/20260328000001_fix_leaderboard_audit.sql` | Fix league reset, auth checks, total_count, drop stale RLS |
| Create | `packages/owlio_shared/lib/src/constants/league_constants.dart` | Shared `leagueZoneSize()` function |
| Modify | `packages/owlio_shared/lib/owlio_shared.dart` | Export new constants file |
| Modify | `lib/domain/entities/leaderboard_entry.dart` | Add `totalCount` field |
| Modify | `lib/data/models/user/leaderboard_entry_model.dart` | Parse `total_count` from JSON |
| Modify | `lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart` | Rename enum, `LeagueTier` param |
| Modify | `lib/domain/usecases/user/get_user_weekly_position_usecase.dart` | Update enum reference, `LeagueTier` param |
| Modify | `lib/domain/repositories/user_repository.dart` | `LeagueTier?` param type |
| Modify | `lib/data/repositories/supabase/supabase_user_repository.dart` | Convert `LeagueTier` at data boundary |
| Modify | `lib/presentation/providers/leaderboard_provider.dart` | Remove alias, propagate totalCount, update params |
| Modify | `lib/presentation/screens/leaderboard/leaderboard_screen.dart` | Use shared zone size, fix zone banners, add retry |

---

### Task 1: Database Migration — Fix league reset + auth + total_count + stale RLS

**Files:**
- Create: `supabase/migrations/20260328000001_fix_leaderboard_audit.sql`

- [ ] **Step 1: Create migration file with fixed `process_weekly_league_reset()`**

```sql
-- =============================================
-- Leaderboard Audit Fixes (#12)
-- 1. Fix process_weekly_league_reset: restore tier-based + temp table + app_now()
-- 2. Add auth.uid() checks to all 8 read RPCs
-- 3. Add total_count to get_weekly_school_leaderboard
-- 4. Fix NOW() → app_now() in weekly RPCs
-- 5. Drop stale class-based RLS policy
-- =============================================

-- =============================================
-- 1. Fix process_weekly_league_reset
--    Combines: tier-based (20260218000003) + temp table (20260316000010) + app_now() (20260323000006)
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
    v_tier_order TEXT[] := ARRAY['bronze', 'silver', 'gold', 'platinum', 'diamond'];
    v_school RECORD;
    v_tier TEXT;
    v_student RECORD;
    v_group_size INTEGER;
    v_zone_size INTEGER;
    v_current_idx INTEGER;
    v_new_tier VARCHAR(20);
    v_result VARCHAR(20);
BEGIN
    -- Skip if already processed this week
    IF EXISTS (SELECT 1 FROM league_history WHERE week_start = v_last_week_start LIMIT 1) THEN
        RAISE NOTICE 'Week % already processed', v_last_week_start;
        RETURN;
    END IF;

    -- Step 1: Pre-aggregate ALL weekly XP in a single pass
    CREATE TEMP TABLE IF NOT EXISTS tmp_weekly_xp AS
    SELECT
        xl.user_id,
        COALESCE(SUM(xl.amount), 0)::BIGINT AS week_xp
    FROM xp_logs xl
    WHERE xl.created_at >= v_last_week_ts
    AND xl.created_at < v_this_week_ts
    GROUP BY xl.user_id;

    CREATE INDEX IF NOT EXISTS idx_tmp_weekly_xp_user ON tmp_weekly_xp(user_id);

    -- Step 2: Process each school × tier
    FOR v_school IN
        SELECT DISTINCT p.school_id
        FROM profiles p
        WHERE p.role = 'student' AND p.school_id IS NOT NULL
    LOOP
        FOREACH v_tier IN ARRAY v_tier_order LOOP
            SELECT COUNT(*) INTO v_group_size
            FROM profiles
            WHERE school_id = v_school.school_id AND role = 'student' AND league_tier = v_tier;

            IF v_group_size = 0 THEN CONTINUE; END IF;

            -- Zone size thresholds (must match leagueZoneSize() in owlio_shared)
            IF v_group_size < 10 THEN v_zone_size := 1;
            ELSIF v_group_size <= 25 THEN v_zone_size := 2;
            ELSIF v_group_size <= 50 THEN v_zone_size := 3;
            ELSE v_zone_size := 5;
            END IF;

            v_current_idx := array_position(v_tier_order, v_tier);

            FOR v_student IN
                SELECT
                    p.id AS student_id,
                    p.class_id AS student_class_id,
                    p.league_tier AS current_tier,
                    COALESCE(wxc.week_xp, 0) AS weekly_xp,
                    RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC)::INTEGER AS rank
                FROM profiles p
                LEFT JOIN tmp_weekly_xp wxc ON p.id = wxc.user_id
                WHERE p.school_id = v_school.school_id
                AND p.role = 'student'
                AND p.league_tier = v_tier
                ORDER BY rank
            LOOP
                v_result := 'stayed';
                v_new_tier := v_student.current_tier;

                IF v_student.rank <= v_zone_size AND v_current_idx < 5 THEN
                    v_new_tier := v_tier_order[v_current_idx + 1];
                    v_result := 'promoted';
                ELSIF v_student.rank > (v_group_size - v_zone_size) AND v_current_idx > 1 THEN
                    v_new_tier := v_tier_order[v_current_idx - 1];
                    v_result := 'demoted';
                END IF;

                INSERT INTO league_history (user_id, class_id, school_id, week_start, league_tier, rank, weekly_xp, result)
                VALUES (v_student.student_id, v_student.student_class_id, v_school.school_id,
                        v_last_week_start, v_new_tier, v_student.rank, v_student.weekly_xp, v_result);

                IF v_new_tier != v_student.current_tier THEN
                    UPDATE profiles SET league_tier = v_new_tier WHERE id = v_student.student_id;
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;

    -- Cleanup temp table
    DROP TABLE IF EXISTS tmp_weekly_xp;
END;
$$;

COMMENT ON FUNCTION process_weekly_league_reset IS 'Process weekly league promotion/demotion per school×tier. Zone thresholds must match leagueZoneSize() in owlio_shared. Call every Monday 00:00 UTC.';
```

- [ ] **Step 2: Add auth-checked weekly class leaderboard RPC**

```sql
-- =============================================
-- 2. Redefine all 8 read RPCs with auth checks + app_now()
-- =============================================

-- 2a. get_weekly_class_leaderboard
DROP FUNCTION IF EXISTS get_weekly_class_leaderboard(UUID, INTEGER);

CREATE OR REPLACE FUNCTION get_weekly_class_leaderboard(
    p_class_id UUID,
    p_limit INTEGER DEFAULT 10
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
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
BEGIN
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.class_id = p_class_id
    )
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        COALESCE(wxc.week_xp, 0),
        p.level,
        RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC),
        pw.prev_rank,
        p.league_tier
    FROM profiles p
    LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
    LEFT JOIN prev_week pw ON p.id = pw.uid
    WHERE p.class_id = p_class_id
    AND p.role = 'student'
    ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC
    LIMIT p_limit;
END;
$$;
```

- [ ] **Step 3: Add auth-checked weekly school leaderboard RPC (with total_count)**

```sql
-- 2b. get_weekly_school_leaderboard (+ total_count)
DROP FUNCTION IF EXISTS get_weekly_school_leaderboard(UUID, INTEGER, VARCHAR);

CREATE OR REPLACE FUNCTION get_weekly_school_leaderboard(
    p_school_id UUID,
    p_limit INTEGER DEFAULT 10,
    p_league_tier VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR,
    total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
    v_total_count BIGINT;
BEGIN
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

    -- Count total students in the group (for zone size calculation)
    SELECT COUNT(*) INTO v_total_count
    FROM profiles
    WHERE school_id = p_school_id AND role = 'student'
    AND (p_league_tier IS NULL OR league_tier = p_league_tier);

    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.school_id = p_school_id
    )
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        c.name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        COALESCE(wxc.week_xp, 0),
        p.level,
        RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC),
        pw.prev_rank,
        p.league_tier,
        v_total_count
    FROM profiles p
    LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
    LEFT JOIN prev_week pw ON p.id = pw.uid
    LEFT JOIN classes c ON p.class_id = c.id
    WHERE p.school_id = p_school_id
    AND p.role = 'student'
    AND (p_league_tier IS NULL OR p.league_tier = p_league_tier)
    ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC
    LIMIT p_limit;
END;
$$;
```

- [ ] **Step 4: Add auth-checked user weekly position RPCs**

```sql
-- 2c. get_user_weekly_class_position
DROP FUNCTION IF EXISTS get_user_weekly_class_position(UUID, UUID);

CREATE OR REPLACE FUNCTION get_user_weekly_class_position(
    p_user_id UUID,
    p_class_id UUID
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
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
BEGIN
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.class_id = p_class_id
    ),
    ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            COALESCE(wxc.week_xp, 0) AS week_xp,
            p.level,
            RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC) AS rnk,
            pw.prev_rank,
            p.league_tier
        FROM profiles p
        LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
        LEFT JOIN prev_week pw ON p.id = pw.uid
        WHERE p.class_id = p_class_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.week_xp, r.level, r.rnk, r.prev_rank, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

-- 2d. get_user_weekly_school_position
DROP FUNCTION IF EXISTS get_user_weekly_school_position(UUID, UUID, VARCHAR);

CREATE OR REPLACE FUNCTION get_user_weekly_school_position(
    p_user_id UUID,
    p_school_id UUID,
    p_league_tier VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    total_xp INTEGER,
    weekly_xp BIGINT,
    level INTEGER,
    rank BIGINT,
    previous_rank INTEGER,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_week_start TIMESTAMPTZ := date_trunc('week', app_now());
    v_prev_week_start DATE := (date_trunc('week', app_now()) - INTERVAL '7 days')::DATE;
BEGIN
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

    RETURN QUERY
    WITH weekly_xp_calc AS (
        SELECT
            xl.user_id AS uid,
            COALESCE(SUM(xl.amount), 0) AS week_xp
        FROM xp_logs xl
        WHERE xl.created_at >= v_week_start
        GROUP BY xl.user_id
    ),
    prev_week AS (
        SELECT
            lh.user_id AS uid,
            lh.rank AS prev_rank
        FROM league_history lh
        WHERE lh.week_start = v_prev_week_start
        AND lh.school_id = p_school_id
    ),
    ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            c.name AS class_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            COALESCE(wxc.week_xp, 0) AS week_xp,
            p.level,
            RANK() OVER (ORDER BY COALESCE(wxc.week_xp, 0) DESC, p.xp DESC) AS rnk,
            pw.prev_rank,
            p.league_tier
        FROM profiles p
        LEFT JOIN weekly_xp_calc wxc ON p.id = wxc.uid
        LEFT JOIN prev_week pw ON p.id = pw.uid
        LEFT JOIN classes c ON p.class_id = c.id
        WHERE p.school_id = p_school_id
        AND p.role = 'student'
        AND (p_league_tier IS NULL OR p.league_tier = p_league_tier)
    )
    SELECT r.id, r.first_name, r.last_name, r.class_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.week_xp, r.level, r.rnk, r.prev_rank, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;
```

- [ ] **Step 5: Add auth-checked total leaderboard RPCs**

```sql
-- 2e. get_class_leaderboard
DROP FUNCTION IF EXISTS get_class_leaderboard(UUID, INTEGER);

CREATE OR REPLACE FUNCTION get_class_leaderboard(
    p_class_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        p.level,
        RANK() OVER (ORDER BY p.xp DESC),
        p.league_tier
    FROM profiles p
    WHERE p.class_id = p_class_id
    AND p.role = 'student'
    ORDER BY p.xp DESC
    LIMIT p_limit;
END;
$$;

-- 2f. get_school_leaderboard
DROP FUNCTION IF EXISTS get_school_leaderboard(UUID, INTEGER);

CREATE OR REPLACE FUNCTION get_school_leaderboard(
    p_school_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.first_name,
        p.last_name,
        c.name,
        p.avatar_url,
        p.avatar_equipped_cache,
        p.xp,
        p.level,
        RANK() OVER (ORDER BY p.xp DESC),
        p.league_tier
    FROM profiles p
    LEFT JOIN classes c ON p.class_id = c.id
    WHERE p.school_id = p_school_id
    AND p.role = 'student'
    ORDER BY p.xp DESC
    LIMIT p_limit;
END;
$$;

-- 2g. get_user_class_position
DROP FUNCTION IF EXISTS get_user_class_position(UUID, UUID);

CREATE OR REPLACE FUNCTION get_user_class_position(
    p_user_id UUID,
    p_class_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    -- Auth check: caller must belong to this class
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND class_id = p_class_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this class';
    END IF;

    RETURN QUERY
    WITH ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            p.level,
            RANK() OVER (ORDER BY p.xp DESC) AS rnk,
            p.league_tier
        FROM profiles p
        WHERE p.class_id = p_class_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.level, r.rnk, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;

-- 2h. get_user_school_position
DROP FUNCTION IF EXISTS get_user_school_position(UUID, UUID);

CREATE OR REPLACE FUNCTION get_user_school_position(
    p_user_id UUID,
    p_school_id UUID
)
RETURNS TABLE(
    user_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    class_name VARCHAR,
    avatar_url VARCHAR,
    avatar_equipped_cache JSONB,
    xp INTEGER,
    level INTEGER,
    rank BIGINT,
    league_tier VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
    -- Auth check: caller must belong to this school
    IF NOT EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND school_id = p_school_id
    ) THEN
        RAISE EXCEPTION 'Access denied: caller does not belong to this school';
    END IF;

    RETURN QUERY
    WITH ranked AS (
        SELECT
            p.id,
            p.first_name,
            p.last_name,
            c.name AS class_name,
            p.avatar_url,
            p.avatar_equipped_cache,
            p.xp,
            p.level,
            RANK() OVER (ORDER BY p.xp DESC) AS rnk,
            p.league_tier
        FROM profiles p
        LEFT JOIN classes c ON p.class_id = c.id
        WHERE p.school_id = p_school_id
        AND p.role = 'student'
    )
    SELECT r.id, r.first_name, r.last_name, r.class_name, r.avatar_url, r.avatar_equipped_cache,
           r.xp, r.level, r.rnk, r.league_tier
    FROM ranked r
    WHERE r.id = p_user_id;
END;
$$;
```

- [ ] **Step 6: Drop stale RLS policy**

```sql
-- =============================================
-- 3. Drop stale class-based RLS policy (replaced by school-based policy)
-- =============================================
DROP POLICY IF EXISTS "Users can read classmates league history" ON league_history;
```

- [ ] **Step 7: Dry-run the migration**

Run: `supabase db push --dry-run`
Expected: Shows the SQL that would be applied, no errors.

- [ ] **Step 8: Push migration to remote**

Run: `supabase db push`
Expected: Migration applied successfully.

- [ ] **Step 9: Commit**

```bash
git add supabase/migrations/20260328000001_fix_leaderboard_audit.sql
git commit -m "fix: restore tier-based league reset + add auth checks to leaderboard RPCs (#12 audit)"
```

---

### Task 2: Shared Package — `leagueZoneSize()` constant

**Files:**
- Create: `packages/owlio_shared/lib/src/constants/league_constants.dart`
- Modify: `packages/owlio_shared/lib/owlio_shared.dart`

- [ ] **Step 1: Create league constants file**

Create `packages/owlio_shared/lib/src/constants/league_constants.dart`:

```dart
/// Zone size for league promotion/demotion.
///
/// Determines how many students promote/demote per weekly reset.
/// Must match the thresholds in process_weekly_league_reset() SQL function.
int leagueZoneSize(int groupSize) {
  if (groupSize < 10) return 1;
  if (groupSize <= 25) return 2;
  if (groupSize <= 50) return 3;
  return 5;
}
```

- [ ] **Step 2: Export from shared package**

Add to `packages/owlio_shared/lib/owlio_shared.dart`:

```dart
export 'src/constants/league_constants.dart';
```

- [ ] **Step 3: Verify shared package compiles**

Run: `cd packages/owlio_shared && dart analyze lib/`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add packages/owlio_shared/lib/src/constants/league_constants.dart packages/owlio_shared/lib/owlio_shared.dart
git commit -m "feat: add leagueZoneSize() to owlio_shared (#12 audit fix 5)"
```

---

### Task 3: Domain/Data Layer — totalCount, enum rename, LeagueTier params

**Files:**
- Modify: `lib/domain/entities/leaderboard_entry.dart`
- Modify: `lib/data/models/user/leaderboard_entry_model.dart`
- Modify: `lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart`
- Modify: `lib/domain/usecases/user/get_user_weekly_position_usecase.dart`
- Modify: `lib/domain/repositories/user_repository.dart`
- Modify: `lib/data/repositories/supabase/supabase_user_repository.dart`

- [ ] **Step 1: Add `totalCount` to `LeaderboardEntry` entity**

In `lib/domain/entities/leaderboard_entry.dart`, add field to constructor and props:

```dart
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
  });
```

Add field declaration:
```dart
  final int? totalCount;
```

Add to props list:
```dart
  @override
  List<Object?> get props => [
        userId,
        firstName,
        lastName,
        avatarUrl,
        avatarEquippedCache,
        totalXp,
        weeklyXp,
        level,
        rank,
        previousRank,
        className,
        leagueTier,
        totalCount,
      ];
```

- [ ] **Step 2: Parse `total_count` in `LeaderboardEntryModel`**

In `lib/data/models/user/leaderboard_entry_model.dart`, add to `fromJson`:

```dart
totalCount: (json['total_count'] as num?)?.toInt(),
```

Add field declaration:
```dart
  final int? totalCount;
```

Add to constructor:
```dart
    this.totalCount,
```

Add to `toEntity()`:
```dart
      totalCount: totalCount,
```

- [ ] **Step 3: Rename `LeaderboardScope` to `WeeklyLeaderboardScope` in weekly usecase**

In `lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart`:

Change line 8:
```dart
enum WeeklyLeaderboardScope { classScope, schoolScope }
```

Change `GetWeeklyLeaderboardParams`:
```dart
class GetWeeklyLeaderboardParams {
  const GetWeeklyLeaderboardParams({
    required this.scope,
    this.classId,
    this.schoolId,
    this.limit = 10,
    this.leagueTier,
  });

  final WeeklyLeaderboardScope scope;
  final String? classId;
  final String? schoolId;
  final int limit;
  final LeagueTier? leagueTier;
}
```

Add import at top:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Update the `call` method:
```dart
    if (params.scope == WeeklyLeaderboardScope.classScope) {
```

- [ ] **Step 4: Update `GetUserWeeklyPositionUseCase` for renamed enum and `LeagueTier` param**

In `lib/domain/usecases/user/get_user_weekly_position_usecase.dart`:

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Change `GetUserWeeklyPositionParams`:
```dart
class GetUserWeeklyPositionParams {
  const GetUserWeeklyPositionParams({
    required this.userId,
    required this.scope,
    this.classId,
    this.schoolId,
    this.leagueTier,
  });

  final String userId;
  final WeeklyLeaderboardScope scope;
  final String? classId;
  final String? schoolId;
  final LeagueTier? leagueTier;
}
```

Update the `call` method:
```dart
    if (params.scope == WeeklyLeaderboardScope.classScope) {
```

- [ ] **Step 5: Update repository interface — `LeagueTier?` params**

In `lib/domain/repositories/user_repository.dart`, change both methods:

```dart
  /// Get weekly school leaderboard (ranked by weekly XP since Monday)
  /// When [leagueTier] is provided, ranks within that tier only.
  Future<Either<Failure, List<LeaderboardEntry>>> getWeeklySchoolLeaderboard({
    required String schoolId,
    int limit = 10,
    LeagueTier? leagueTier,
  });

  /// Get current user's position in weekly school leaderboard
  /// When [leagueTier] is provided, ranks within that tier only.
  Future<Either<Failure, LeaderboardEntry>> getUserWeeklySchoolPosition({
    required String userId,
    required String schoolId,
    LeagueTier? leagueTier,
  });
```

Add import at top if not already present:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

- [ ] **Step 6: Update repository implementation — convert `LeagueTier` at data boundary**

In `lib/data/repositories/supabase/supabase_user_repository.dart`:

For `getWeeklySchoolLeaderboard` (around line 439):
```dart
  Future<Either<Failure, List<LeaderboardEntry>>> getWeeklySchoolLeaderboard({
    required String schoolId,
    int limit = 10,
    LeagueTier? leagueTier,
  }) async {
```
And change the params line:
```dart
      if (leagueTier != null) params['p_league_tier'] = leagueTier.dbValue;
```

For `getUserWeeklySchoolPosition` (around line 501):
```dart
  Future<Either<Failure, LeaderboardEntry>> getUserWeeklySchoolPosition({
    required String userId,
    required String schoolId,
    LeagueTier? leagueTier,
  }) async {
```
And change the params line:
```dart
      if (leagueTier != null) params['p_league_tier'] = leagueTier.dbValue;
```

Add import at top if not already present:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

- [ ] **Step 7: Verify with dart analyze**

Run: `dart analyze lib/`
Expected: No issues (or only pre-existing issues unrelated to leaderboard).

- [ ] **Step 8: Commit**

```bash
git add lib/domain/entities/leaderboard_entry.dart lib/data/models/user/leaderboard_entry_model.dart lib/domain/usecases/user/get_weekly_leaderboard_usecase.dart lib/domain/usecases/user/get_user_weekly_position_usecase.dart lib/domain/repositories/user_repository.dart lib/data/repositories/supabase/supabase_user_repository.dart
git commit -m "refactor: add totalCount, rename WeeklyLeaderboardScope, type-safe LeagueTier params (#12 audit fix 3,4,6)"
```

---

### Task 4: Presentation Layer — provider, zone fix, retry button

**Files:**
- Modify: `lib/presentation/providers/leaderboard_provider.dart`
- Modify: `lib/presentation/screens/leaderboard/leaderboard_screen.dart`

- [ ] **Step 1: Update `leaderboard_provider.dart` — remove alias, fix params, add totalCount**

Replace the full import + alias block (lines 7-9):
```dart
import '../../domain/usecases/user/get_weekly_leaderboard_usecase.dart';
import '../../domain/usecases/user/get_user_weekly_position_usecase.dart';
```

Update `leaderboardEntriesProvider` league scope branch (around line 47-56):
```dart
    // leagueScope — weekly school leaderboard (within user's tier)
    final useCase = ref.watch(getWeeklyLeaderboardUseCaseProvider);
    final result = await useCase(GetWeeklyLeaderboardParams(
      scope: WeeklyLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
      leagueTier: currentUser.leagueTier,
      limit: 50,
    ));
    return result.fold((_) => [], (entries) => entries);
```

Update `currentUserPositionProvider` league scope branch (around line 84-94):
```dart
    // leagueScope — user's weekly position in school (within user's tier)
    final useCase = ref.watch(getUserWeeklyPositionUseCaseProvider);
    final result = await useCase(GetUserWeeklyPositionParams(
      userId: currentUser.id,
      scope: WeeklyLeaderboardScope.schoolScope,
      schoolId: currentUser.schoolId,
      leagueTier: currentUser.leagueTier,
    ));
    return result.fold((_) => null, (entry) => entry);
```

Add `leagueTotalCount` to `LeaderboardDisplayState`:
```dart
class LeaderboardDisplayState {
  const LeaderboardDisplayState({
    required this.entries,
    required this.currentUserEntry,
    required this.currentUserId,
    this.scope = LeaderboardScope.classScope,
    this.leagueTotalCount,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;
  final String currentUserId;
  final LeaderboardScope scope;
  final int? leagueTotalCount;
```

In `leaderboardDisplayProvider`, add to the return statement:
```dart
  return LeaderboardDisplayState(
    entries: entries,
    currentUserEntry: isInList ? null : userPosition,
    currentUserId: currentUser.id,
    scope: scope,
    leagueTotalCount: scope == LeaderboardScope.leagueScope && entries.isNotEmpty
        ? entries.first.totalCount
        : null,
  );
```

- [ ] **Step 2: Update `leaderboard_screen.dart` — shared zone size, fix banner, add retry**

Remove local `_leagueZoneSize` function (lines 17-23).

Add import:
```dart
import 'package:owlio_shared/owlio_shared.dart';
```

Add import for ErrorStateWidget:
```dart
import '../../widgets/common/error_state_widget.dart';
```

Replace error handling in build method (around line 59-62):
```dart
              error: (e, _) => ErrorStateWidget(
                message: 'Could not load leaderboard',
                onRetry: () => ref.invalidate(leaderboardDisplayProvider),
              ),
```

In `_ZonePreviewBanner.build()`, replace zone calculation (around line 263-264):
```dart
    final totalEntries = state.leagueTotalCount ?? state.totalCount;
    final zoneSize = leagueZoneSize(totalEntries);
```

In `_buildEntryCard`, replace zone calculation (around lines 388-389):
```dart
      final totalEntries = state.leagueTotalCount ?? state.totalCount;
      final zoneSize = leagueZoneSize(totalEntries);
```

- [ ] **Step 3: Verify with dart analyze**

Run: `dart analyze lib/`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/leaderboard_provider.dart lib/presentation/screens/leaderboard/leaderboard_screen.dart
git commit -m "fix: accurate zone banners with total_count, add retry, shared zone size (#12 audit fix 3,4,5,10)"
```

---

### Task 5: Update Feature Spec — mark findings as fixed

**Files:**
- Modify: `docs/specs/12-leaderboard-leagues.md`

- [ ] **Step 1: Update audit findings table**

In `docs/specs/12-leaderboard-leagues.md`, update the Status column for each fixed issue:

| # | Status change |
|---|--------------|
| 1 | TODO → Fixed |
| 2 | TODO → Fixed |
| 3 | TODO → Fixed |
| 4 | TODO → Fixed |
| 5 | TODO → Fixed |
| 6 | TODO → Fixed |
| 9 | TODO → Fixed |
| 10 | TODO → Fixed |

Issues #7 and #8 remain TODO (out of scope).

- [ ] **Step 2: Update Known Issues section**

Remove items 1-6 from the Known Issues list (they are now fixed). Keep items 6 (`notif_league_change` placeholder) and 7 (teacher leaderboard) renumbered as 1-2.

- [ ] **Step 3: Commit**

```bash
git add docs/specs/12-leaderboard-leagues.md
git commit -m "docs: update leaderboard spec — mark 8 audit findings as fixed"
```
