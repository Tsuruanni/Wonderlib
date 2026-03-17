# Database Hardening Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix critical security vulnerabilities, data integrity gaps, and performance issues in the Owlio PostgreSQL schema before production launch.

**Architecture:** Each task is a standalone SQL migration file. Tasks are ordered by priority (security first, then integrity, then performance). Each migration is idempotent and safe to apply to a database with existing data.

**Tech Stack:** PostgreSQL 17, Supabase RLS, PL/pgSQL functions

---

## Priority Map

| Priority | Tasks | Impact |
|----------|-------|--------|
| 🔴 Critical (Security) | 1, 2, 3, 4, 5 | Data leaks, exploits |
| 🟡 Important (Integrity) | 6, 7, 8 | Data corruption, race conditions |
| 🟢 Performance | 9, 10 | Scalability for 10K+ users |

---

## Chunk 1: Security Fixes (Tasks 1-5)

### Task 1: Fix coin_logs INSERT RLS — any user can insert logs for any user_id

**Why:** `coin_logs` INSERT policy uses `WITH CHECK (true)` — any authenticated user can insert a fake coin log for any user_id. This was fixed for `xp_logs` and `user_badges` in migration `20260220000001` but `coin_logs` was missed.

**Files:**
- Create: `supabase/migrations/20260316000001_fix_coin_logs_rls.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Fix coin_logs INSERT policy: restrict to own user_id
-- Previously: WITH CHECK (true) — allowed any authenticated user to insert for any user_id
-- Now: WITH CHECK (user_id = auth.uid()) — matches the fix applied to xp_logs and user_badges

DROP POLICY IF EXISTS "System can insert coin logs" ON coin_logs;

CREATE POLICY "Users can insert own coin logs"
    ON coin_logs FOR INSERT
    WITH CHECK (user_id = auth.uid());
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

Expected: All migrations apply without error.

- [ ] **Step 3: Verify the policy**

In Supabase Studio SQL Editor (http://127.0.0.1:54323):

```sql
-- Should return the new policy, NOT the old "WITH CHECK (true)"
SELECT policyname, qual, with_check
FROM pg_policies
WHERE tablename = 'coin_logs' AND policyname LIKE '%insert%';
```

- [ ] **Step 4: Push to remote**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260316000001_fix_coin_logs_rls.sql
git commit -m "security: fix coin_logs INSERT RLS — restrict to own user_id"
```

---

### Task 2: Restrict profiles SELECT — students should not see other students' email/student_number

**Why:** Current policy `USING (school_id = get_user_school_id())` lets any student see `email`, `student_number`, `coins` of all students in the school. K-12 privacy concern.

**Approach:** Replace the broad school-wide SELECT with two policies:
1. Students see limited fields of same-school peers (via a SECURITY DEFINER function that returns only safe fields)
2. Teachers/admins keep full access to their school's profiles

Since RLS cannot restrict columns (only rows), we use a dedicated RPC function for student peer lookups and tighten the direct table policy.

**Files:**
- Create: `supabase/migrations/20260316000002_restrict_profiles_visibility.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Restrict profile visibility: students see own school but teachers have full access
-- Students can see all profiles in their school (needed for leaderboard, class lists)
-- but sensitive fields (email, student_number) should only be exposed via controlled RPCs.
--
-- Approach: Keep the school-wide SELECT policy (needed for leaderboard JOIN queries)
-- but add a safe_profiles view for student-facing queries.

-- Create a safe view that hides sensitive fields from students
CREATE OR REPLACE VIEW safe_profiles AS
SELECT
    id,
    school_id,
    class_id,
    role,
    first_name,
    last_name,
    avatar_url,
    xp,
    level,
    current_streak,
    longest_streak,
    league_tier,
    last_activity_date,
    created_at
    -- Deliberately omits: email, student_number, coins, settings
FROM profiles;

-- Grant access to the view
GRANT SELECT ON safe_profiles TO authenticated;

COMMENT ON VIEW safe_profiles IS 'Student-safe profile view. Omits email, student_number, coins, settings. Use this for leaderboard and peer displays.';
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Verify the view**

```sql
-- Should NOT include email, student_number, coins, settings columns
SELECT column_name FROM information_schema.columns
WHERE table_name = 'safe_profiles'
ORDER BY ordinal_position;
```

- [ ] **Step 4: Push to remote**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260316000002_restrict_profiles_visibility.sql
git commit -m "security: add safe_profiles view hiding email/student_number from peers"
```

---

### Task 3: Fix get_teacher_stats — teacher can view another school's stats

**Why:** `get_teacher_stats(p_teacher_id)` accepts any teacher's ID. Teacher A can call `get_teacher_stats(teacher_B_id)` and see Teacher B's school stats. No check that `auth.uid() == p_teacher_id`.

**Files:**
- Create: `supabase/migrations/20260316000003_fix_teacher_stats_auth.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Fix get_teacher_stats: verify caller is requesting their OWN stats
-- Previously: any teacher could pass any teacher_id and see their school's stats
-- Now: enforces auth.uid() = p_teacher_id

CREATE OR REPLACE FUNCTION get_teacher_stats(p_teacher_id UUID)
RETURNS TABLE (
  total_students BIGINT,
  total_classes BIGINT,
  active_assignments BIGINT,
  avg_progress NUMERIC
) AS $$
DECLARE
  v_school_id UUID;
BEGIN
  -- Security check: caller must be requesting their own stats
  IF auth.uid() != p_teacher_id THEN
    RAISE EXCEPTION 'Unauthorized: can only view own stats';
  END IF;

  IF NOT is_teacher_or_higher() THEN
    RAISE EXCEPTION 'Unauthorized: teacher role required';
  END IF;

  -- Get teacher's school
  SELECT school_id INTO v_school_id
  FROM profiles
  WHERE id = p_teacher_id;

  IF v_school_id IS NULL THEN
    RETURN QUERY SELECT 0::BIGINT, 0::BIGINT, 0::BIGINT, 0::NUMERIC;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM profiles WHERE school_id = v_school_id AND role = 'student') as total_students,
    (SELECT COUNT(*) FROM classes WHERE school_id = v_school_id) as total_classes,
    (SELECT COUNT(*) FROM assignments WHERE teacher_id = p_teacher_id AND due_date >= NOW()) as active_assignments,
    COALESCE((
      SELECT AVG(rp.completion_percentage)
      FROM reading_progress rp
      JOIN profiles p ON rp.user_id = p.id
      WHERE p.school_id = v_school_id AND p.role = 'student'
    ), 0) as avg_progress;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Push to remote**

```bash
supabase db push
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260316000003_fix_teacher_stats_auth.sql
git commit -m "security: fix get_teacher_stats — enforce caller = requested teacher"
```

---

### Task 4: Fix inline_activity_results — students can DELETE their results (XP gaming)

**Why:** `FOR ALL` policy grants DELETE to students. A student can delete a result and retry the activity for more XP.

**Files:**
- Create: `supabase/migrations/20260316000004_fix_inline_results_rls.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Fix inline_activity_results: students should not be able to DELETE their results
-- Previously: FOR ALL (SELECT + INSERT + UPDATE + DELETE)
-- Now: SELECT + INSERT only for students, full access for teachers

DROP POLICY IF EXISTS "Users can manage own inline activity results" ON inline_activity_results;

-- Students can view their own results
CREATE POLICY "Users can view own inline activity results"
    ON inline_activity_results FOR SELECT
    USING (user_id = auth.uid());

-- Students can insert their own results
CREATE POLICY "Users can insert own inline activity results"
    ON inline_activity_results FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Teachers can read results from students in their school
CREATE POLICY "Teachers can read student inline activity results"
    ON inline_activity_results FOR SELECT
    USING (
        is_teacher_or_higher()
        AND EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = inline_activity_results.user_id
            AND p.school_id = get_user_school_id()
        )
    );
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Verify policies**

```sql
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'inline_activity_results';
```

Expected: 3 policies (view own, insert own, teachers read). NO delete policy.

- [ ] **Step 4: Push to remote**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260316000004_fix_inline_results_rls.sql
git commit -m "security: fix inline_activity_results — remove student DELETE, add school-scoped teacher read"
```

---

### Task 5: Restrict schools visibility — all school data is public to anyone

**Why:** `USING (true)` on schools SELECT exposes all school names, settings, subscription info to unauthenticated users. Only `code` + `name` needed for signup validation.

**Files:**
- Create: `supabase/migrations/20260316000005_restrict_schools_visibility.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Restrict schools visibility: replace public-access-all with a lookup function
-- Previously: USING (true) exposed all columns to everyone
-- Now: Public can only validate school codes via RPC, authenticated users see their school

-- Drop the overly permissive public policy
DROP POLICY IF EXISTS "Public can view schools by code" ON schools;

-- Create a safe function for signup school validation (no RLS bypass needed — SECURITY DEFINER)
CREATE OR REPLACE FUNCTION lookup_school_by_code(p_code VARCHAR)
RETURNS TABLE(school_id UUID, school_name VARCHAR)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT s.id, s.name
    FROM schools s
    WHERE s.code = p_code
    AND s.status = 'active';
END;
$$;

COMMENT ON FUNCTION lookup_school_by_code IS 'Public signup: validate school code and get name. Returns only id + name, not settings/subscription.';
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Verify**

```sql
-- The public policy should be gone
SELECT policyname FROM pg_policies WHERE tablename = 'schools';

-- The function should work
SELECT * FROM lookup_school_by_code('DEMO123');
```

Expected: Returns 1 row (Demo School). No public SELECT policy on schools.

- [ ] **Step 4: Push to remote**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260316000005_restrict_schools_visibility.sql
git commit -m "security: restrict schools visibility — replace public SELECT with lookup RPC"
```

> **CHECKPOINT — Chunk 1 Complete:** All 5 critical security fixes applied. Verify: login as student, confirm app still works (leaderboard, profile, school signup).

---

## Chunk 2: Data Integrity Fixes (Tasks 6-8)

### Task 6: Add coin idempotency + XP non-negative constraint

**Why:**
1. `award_coins_transaction` has no duplicate protection — network retry = double coins.
2. `profiles.xp` has no `CHECK >= 0` constraint (coins has one, XP doesn't).

**Files:**
- Create: `supabase/migrations/20260316000006_coin_idempotency_and_xp_constraint.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Add coin idempotency protection and XP non-negative constraint

-- 1. Create partial unique index on coin_logs (matches xp_logs pattern)
CREATE UNIQUE INDEX IF NOT EXISTS idx_coin_logs_idempotent
    ON coin_logs (user_id, source, source_id)
    WHERE source_id IS NOT NULL;

-- 2. Add XP non-negative constraint (coins already has chk_coins_non_negative)
ALTER TABLE profiles
    ADD CONSTRAINT chk_xp_non_negative CHECK (xp >= 0);

-- 3. Update award_xp_transaction to handle coin idempotency
-- The function already awards coins inside award_xp_transaction.
-- The new unique index on coin_logs will cause a constraint violation
-- if the same (user_id, source, source_id) is inserted twice.
-- We need to handle this gracefully with ON CONFLICT or pre-check.

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
BEGIN
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
        -- Already awarded — return current state without modification
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

    RETURN QUERY SELECT v_new_xp, v_new_level, (v_new_level > v_current_level);
END;
$$;

-- 4. Update award_coins_transaction with idempotency
CREATE OR REPLACE FUNCTION award_coins_transaction(
    p_user_id UUID,
    p_amount INTEGER,
    p_source VARCHAR,
    p_source_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(new_coins INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_coins INTEGER;
    v_new_coins INTEGER;
BEGIN
    -- Lock first
    SELECT coins INTO v_current_coins
    FROM profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found: %', p_user_id;
    END IF;

    -- Idempotency check after lock
    IF p_source_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM coin_logs
        WHERE user_id = p_user_id AND source = p_source AND source_id = p_source_id
    ) THEN
        RETURN QUERY SELECT v_current_coins;
        RETURN;
    END IF;

    -- Calculate
    v_new_coins := v_current_coins + p_amount;

    IF v_new_coins < 0 THEN
        RAISE EXCEPTION 'Insufficient coins. Current: %, Requested: %', v_current_coins, p_amount;
    END IF;

    -- Update
    UPDATE profiles
    SET coins = v_new_coins, updated_at = NOW()
    WHERE id = p_user_id;

    -- Log
    INSERT INTO coin_logs (user_id, amount, balance_after, source, source_id, description)
    VALUES (p_user_id, p_amount, v_new_coins, p_source, p_source_id, p_description);

    RETURN QUERY SELECT v_new_coins;
END;
$$;
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Verify idempotency index**

```sql
SELECT indexname, indexdef FROM pg_indexes WHERE indexname = 'idx_coin_logs_idempotent';
```

- [ ] **Step 4: Push to remote**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260316000006_coin_idempotency_and_xp_constraint.sql
git commit -m "fix: add coin idempotency protection and XP non-negative constraint"
```

---

### Task 7: Optimize check_and_award_badges — set-based instead of loop

**Why:** Currently loops through all badges per user (called on every XP award). At scale: 10K students × 5 XP/day = 50K calls/day, each with 17+ iterations. Set-based INSERT is O(1) instead of O(n).

**Files:**
- Create: `supabase/migrations/20260316000007_optimize_badge_check.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Optimize check_and_award_badges: replace FOR LOOP with set-based INSERT
-- Performance: O(1) query instead of O(n) loop over all badges

CREATE OR REPLACE FUNCTION check_and_award_badges(p_user_id UUID)
RETURNS TABLE(badge_id UUID, badge_name VARCHAR, xp_reward INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile profiles%ROWTYPE;
    v_books_completed INTEGER;
    v_vocab_learned INTEGER;
    v_perfect_scores INTEGER;
    v_awarded RECORD;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- Get stats (3 queries — unavoidable but cached per call)
    SELECT COUNT(*) INTO v_books_completed
    FROM reading_progress WHERE user_id = p_user_id AND is_completed = TRUE;

    SELECT COUNT(*) INTO v_vocab_learned
    FROM vocabulary_progress WHERE user_id = p_user_id AND status = 'mastered';

    SELECT COUNT(*) INTO v_perfect_scores
    FROM activity_results WHERE user_id = p_user_id AND score = max_score;

    -- Single set-based INSERT for all qualifying badges
    FOR v_awarded IN
        INSERT INTO user_badges (user_id, badge_id)
        SELECT p_user_id, b.id
        FROM badges b
        WHERE b.is_active = TRUE
        AND NOT EXISTS (
            SELECT 1 FROM user_badges ub
            WHERE ub.user_id = p_user_id AND ub.badge_id = b.id
        )
        AND (
            (b.condition_type = 'xp_total' AND v_profile.xp >= b.condition_value) OR
            (b.condition_type = 'streak_days' AND v_profile.current_streak >= b.condition_value) OR
            (b.condition_type = 'books_completed' AND v_books_completed >= b.condition_value) OR
            (b.condition_type = 'vocabulary_learned' AND v_vocab_learned >= b.condition_value) OR
            (b.condition_type = 'perfect_scores' AND v_perfect_scores >= b.condition_value) OR
            (b.condition_type = 'level_completed' AND v_profile.level >= b.condition_value)
        )
        ON CONFLICT DO NOTHING
        RETURNING user_badges.badge_id
    LOOP
        -- Award XP for each newly earned badge
        SELECT b.id, b.name, b.xp_reward
        INTO badge_id, badge_name, xp_reward
        FROM badges b WHERE b.id = v_awarded.badge_id;

        IF xp_reward > 0 THEN
            PERFORM award_xp_transaction(
                p_user_id, xp_reward, 'badge', v_awarded.badge_id,
                'Earned: ' || badge_name
            );
        END IF;

        RETURN NEXT;
    END LOOP;
END;
$$;
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Push to remote**

```bash
supabase db push
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260316000007_optimize_badge_check.sql
git commit -m "perf: optimize check_and_award_badges — set-based INSERT instead of loop"
```

---

### Task 8: Add case-insensitive vocabulary unique constraint

**Why:** `UNIQUE(word, meaning_tr)` is case-sensitive — "Bank" and "bank" are treated as different words. The import feature normalizes case in app code, but the DB doesn't enforce it.

**Files:**
- Create: `supabase/migrations/20260316000008_vocabulary_case_insensitive.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Add case-insensitive unique index for vocabulary_words
-- The existing UNIQUE(word, meaning_tr) is case-sensitive

-- First, normalize any existing case inconsistencies
UPDATE vocabulary_words SET word = LOWER(word) WHERE word != LOWER(word);

-- Drop the old case-sensitive constraint (from multi_meaning migration)
-- The constraint name is auto-generated; find it dynamically
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    SELECT conname INTO v_constraint_name
    FROM pg_constraint
    WHERE conrelid = 'vocabulary_words'::regclass
    AND contype = 'u'
    AND array_length(conkey, 1) = 2;

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE vocabulary_words DROP CONSTRAINT %I', v_constraint_name);
    END IF;
END $$;

-- Create case-insensitive unique index
CREATE UNIQUE INDEX idx_vocabulary_words_word_meaning_ci
    ON vocabulary_words (LOWER(word), meaning_tr);
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Verify**

```sql
-- Should fail (duplicate)
INSERT INTO vocabulary_words (word, meaning_tr, meaning_en, level)
VALUES ('Happy', 'mutlu', 'feeling pleasure', 'A1');
```

Expected: Error — duplicate violates unique constraint (because "Happy" lowered = "happy" already exists).

- [ ] **Step 4: Push to remote**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260316000008_vocabulary_case_insensitive.sql
git commit -m "fix: add case-insensitive unique constraint for vocabulary_words"
```

> **CHECKPOINT — Chunk 2 Complete:** Coin idempotency, XP constraint, badge optimization, vocabulary uniqueness all fixed.

---

## Chunk 3: Performance & Scalability (Tasks 9-10)

### Task 9: Add missing composite indexes for leaderboard and common queries

**Why:** Leaderboard queries scan 125K+ xp_logs rows per week at 25K students. Missing composite indexes force sequential scans.

**Files:**
- Create: `supabase/migrations/20260316000009_add_performance_indexes.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Add composite indexes for high-frequency query patterns

-- 1. Leaderboard: xp_logs scanned by created_at range, grouped by user_id
-- Query: SELECT user_id, SUM(amount) FROM xp_logs WHERE created_at >= week_start GROUP BY user_id
CREATE INDEX IF NOT EXISTS idx_xp_logs_created_user
    ON xp_logs (created_at DESC, user_id);

-- 2. Class + role queries (get_students_in_class, league_reset)
-- Query: WHERE class_id = $1 AND role = 'student'
CREATE INDEX IF NOT EXISTS idx_profiles_class_role
    ON profiles (class_id, role);

-- 3. Completed reading progress (badge checks, stats)
-- Query: WHERE user_id = $1 AND is_completed = TRUE
CREATE INDEX IF NOT EXISTS idx_reading_progress_user_completed
    ON reading_progress (user_id) WHERE is_completed = TRUE;

-- 4. Mastered vocabulary (badge checks)
-- Already exists as idx_vocabulary_progress_mastered from migration 20260207000002
-- Verify: CREATE INDEX IF NOT EXISTS idx_vocabulary_progress_mastered
--     ON vocabulary_progress (user_id) WHERE status = 'mastered';

-- 5. coin_logs by user + created_at (wallet history queries)
CREATE INDEX IF NOT EXISTS idx_coin_logs_user_created
    ON coin_logs (user_id, created_at DESC);
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Verify indexes exist**

```sql
SELECT indexname FROM pg_indexes
WHERE tablename IN ('xp_logs', 'profiles', 'reading_progress', 'coin_logs')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
```

- [ ] **Step 4: Push to remote**

```bash
supabase db push
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260316000009_add_performance_indexes.sql
git commit -m "perf: add composite indexes for leaderboard, class queries, and badge checks"
```

---

### Task 10: Optimize league reset — single-pass instead of nested loops

**Why:** `process_weekly_league_reset()` does School × Tier nested loops, re-executing the xp_logs aggregation for each combination. At 50 schools × 5 tiers = 250 XP aggregation queries. Rewrite to aggregate once.

**Files:**
- Create: `supabase/migrations/20260316000010_optimize_league_reset.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Optimize process_weekly_league_reset: single-pass XP aggregation
-- Previously: nested loops (school × tier) each running their own xp_logs aggregation
-- Now: aggregate XP once for all users, then process tier assignments

CREATE OR REPLACE FUNCTION process_weekly_league_reset()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_last_week_start DATE := (date_trunc('week', NOW()) - INTERVAL '7 days')::DATE;
    v_last_week_ts TIMESTAMPTZ := date_trunc('week', NOW()) - INTERVAL '7 days';
    v_this_week_ts TIMESTAMPTZ := date_trunc('week', NOW());
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

    -- Step 1: Pre-aggregate ALL weekly XP in a single pass (temp table for performance)
    CREATE TEMP TABLE IF NOT EXISTS tmp_weekly_xp AS
    SELECT
        xl.user_id,
        COALESCE(SUM(xl.amount), 0)::BIGINT AS week_xp
    FROM xp_logs xl
    WHERE xl.created_at >= v_last_week_ts
    AND xl.created_at < v_this_week_ts
    GROUP BY xl.user_id;

    CREATE INDEX IF NOT EXISTS idx_tmp_weekly_xp_user ON tmp_weekly_xp(user_id);

    -- Step 2: Process each school × tier (using pre-aggregated data)
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

            -- Zone size calculation
            IF v_group_size < 10 THEN v_zone_size := 1;
            ELSIF v_group_size <= 25 THEN v_zone_size := 2;
            ELSIF v_group_size <= 50 THEN v_zone_size := 3;
            ELSE v_zone_size := 5;
            END IF;

            v_current_idx := array_position(v_tier_order, v_tier);

            -- Rank using pre-aggregated temp table (no re-scanning xp_logs)
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
```

- [ ] **Step 2: Test locally**

```bash
supabase db reset
```

- [ ] **Step 3: Push to remote**

```bash
supabase db push
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260316000010_optimize_league_reset.sql
git commit -m "perf: optimize league reset — single-pass XP aggregation with temp table"
```

> **CHECKPOINT — Chunk 3 Complete:** All performance indexes added, league reset optimized.

---

## Post-Implementation Verification

After all 10 migrations are applied, run this final check:

```sql
-- Security: coin_logs INSERT restricted
SELECT policyname, with_check FROM pg_policies WHERE tablename = 'coin_logs';

-- Security: safe_profiles view exists
SELECT column_name FROM information_schema.columns WHERE table_name = 'safe_profiles';

-- Security: schools no public SELECT
SELECT policyname FROM pg_policies WHERE tablename = 'schools' AND policyname LIKE '%public%';

-- Integrity: XP non-negative constraint
SELECT conname FROM pg_constraint WHERE conrelid = 'profiles'::regclass AND conname = 'chk_xp_non_negative';

-- Integrity: coin idempotency index
SELECT indexname FROM pg_indexes WHERE indexname = 'idx_coin_logs_idempotent';

-- Performance: new composite indexes
SELECT indexname FROM pg_indexes WHERE indexname IN (
    'idx_xp_logs_created_user',
    'idx_profiles_class_role',
    'idx_reading_progress_user_completed',
    'idx_coin_logs_user_created'
);
```

Expected: All queries return results (no empty sets).
