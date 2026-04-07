# Database Architecture Audit — Fix Plan

> **Audit Date:** 2026-04-05
> **Overall Score:** 7.5/10
> **Total Issues:** 27
> **Critical (Security):** 5 | **High:** 5 | **Medium:** 9 | **Low:** 8
>
> ## Status
> - **Phase 1:** COMPLETED (2026-04-07) — `20260407000001_database_audit_phase1.sql`
>   - FIX 01-03, 05-11, 17 applied
>   - FIX 01-03 were already fixed in earlier migrations (20260213000002, 20260220000001)
>   - FIX 07 template tables already fixed in 20260327100001; scope tables fixed in Phase 1
>   - FIX 08 class_id FK already fixed in 20260327100001; created_by FKs fixed in Phase 1
> - **Phase 2:** COMPLETED (2026-04-07) — dead code removal + `20260407000004_badge_rls_phase2.sql`
>   - Removed unused awardBadge flow (UseCase, Repository method, Controller, Provider)
>   - Dropped user_badges self-insert RLS policy
> - **Phase 3:** COMPLETED (2026-04-07) — `20260407000007_rpc_n1_fix.sql` + `20260407000008_cleanup_and_constraints.sql`
>   - N+1 CTE refactor for get_class_learning_path_units + get_unit_assignment_items
>   - Dropped orphan daily_quest_pack_claims table + functions
>   - Added source CHECK constraints on xp_logs/coin_logs (NOT VALID for legacy rows)
>   - Added UNIQUE indexes on activity_results/book_quiz_results attempt_number
>   - Fixed badge condition_type CHECK (removed unused daily_login)
>   - FIX-26 (card stats drift) was already fixed in 20260401100002
> - **Deferred:** FIX-18 (system_settings policy), FIX-19 (weekly XP summary), FIX-22 (rename), FIX-25 (array FK), FIX-27 (league reset)

---

## Priority Legend

| Tag | Meaning | Action Timeline |
|-----|---------|-----------------|
| `P0-CRITICAL` | Security vulnerability, data can be manipulated | Immediate |
| `P1-HIGH` | Data integrity risk or cross-school data leak | This week |
| `P2-MEDIUM` | Missing indexes, dead tables, correctness gaps | Next sprint |
| `P3-LOW` | Convention inconsistencies, minor optimizations | Backlog |

---

## P0-CRITICAL — Security Vulnerabilities

### FIX-01: `user_cards` RLS allows any user to modify any user's cards

**Problem:** The `FOR ALL USING (true)` policy means any authenticated user can UPDATE/DELETE
card rows belonging to other users directly through the Supabase client, bypassing the RPC.

**File:** `20260209000005_create_user_cards.sql:72-74`

**Current:**
```sql
CREATE POLICY "System can manage user cards"
    ON user_cards FOR ALL
    USING (true);
```

**Fix:**
```sql
-- Drop the overly permissive policy
DROP POLICY IF EXISTS "System can manage user cards" ON user_cards;

-- Users can only read their own cards (already exists, keep it)
-- The open_card_pack and trade_duplicate_cards RPCs are SECURITY DEFINER,
-- so they bypass RLS and can INSERT/UPDATE freely.

-- No replacement ALL policy needed — SECURITY DEFINER RPCs handle writes.
```

**Verification:** After applying, test that:
1. `supabase.from('user_cards').update({quantity: 999}).eq('user_id', OTHER_USER_ID)` fails
2. `open_card_pack` RPC still works (SECURITY DEFINER bypasses RLS)
3. `trade_duplicate_cards` RPC still works

---

### FIX-02: `user_card_stats` RLS allows any user to modify any user's stats

**Problem:** Same `FOR ALL USING (true)` issue. A user can set their own `packs_since_legendary = 14`
to guarantee a legendary card on next pack open.

**File:** `20260209000005_create_user_cards.sql:98-100`

**Current:**
```sql
CREATE POLICY "System can manage card stats"
    ON user_card_stats FOR ALL
    USING (true);
```

**Fix:**
```sql
-- Drop the overly permissive policy
DROP POLICY IF EXISTS "System can manage card stats" ON user_card_stats;

-- No replacement ALL policy needed — only open_card_pack (SECURITY DEFINER) writes to this table.
```

**Verification:** After applying, test that:
1. `supabase.from('user_card_stats').update({packs_since_legendary: 14}).eq('user_id', MY_ID)` fails
2. `open_card_pack` RPC still writes stats correctly

---

### FIX-03: `xp_logs` INSERT policy allows inserting rows for other users

**Problem:** `WITH CHECK (true)` lets any authenticated user insert fake XP log entries for any
`user_id`. While `profiles.xp` is only updated via RPC, the audit trail (`xp_logs`) can be polluted
with fake entries.

**File:** `20260131000008_create_rls_policies.sql:259-261`

**Current:**
```sql
CREATE POLICY "System can log XP"
    ON xp_logs FOR INSERT
    WITH CHECK (true);
```

**Fix:**
```sql
DROP POLICY IF EXISTS "System can log XP" ON xp_logs;

-- No replacement INSERT policy needed.
-- All XP logging happens through award_xp_transaction (SECURITY DEFINER).
-- Direct client INSERT is never needed.
```

**Verification:** After applying, test that:
1. `supabase.from('xp_logs').insert({user_id: OTHER_ID, amount: 9999, source: 'hack'})` fails
2. `complete_vocabulary_session` RPC still logs XP (calls `award_xp_transaction` internally)
3. `complete_daily_review` RPC still logs XP

---

### FIX-04: `user_badges` INSERT policy allows inserting badges for other users

**Problem:** Same `WITH CHECK (true)` issue. A user can award themselves any badge directly.

**File:** `20260131000008_create_rls_policies.sql:252-253`

**Current:**
```sql
CREATE POLICY "System can award badges"
    ON user_badges FOR INSERT
    WITH CHECK (true);
```

**Fix:**
```sql
DROP POLICY IF EXISTS "System can award badges" ON user_badges;

-- No replacement INSERT policy needed.
-- All badge awarding happens through check_and_award_badges (SECURITY DEFINER).
```

**Note:** Also add a teacher/admin SELECT policy so teachers can view student badges:
```sql
CREATE POLICY "Teachers can view student badges"
    ON user_badges FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = user_badges.user_id
            AND p.school_id = get_user_school_id()
            AND is_teacher_or_higher()
        )
    );
```

**Verification:** After applying, test that:
1. `supabase.from('user_badges').insert({user_id: MY_ID, badge_id: RARE_BADGE})` fails
2. `check_and_award_badges(MY_ID)` still awards badges when conditions are met
3. Teachers can still see student badges

---

### FIX-05: `scope_learning_paths` cross-school data leak

**Problem:** `USING (auth.role() = 'authenticated')` exposes ALL school's learning paths to ALL
authenticated users. School A students can see School B's curriculum structure.

Affects 3 tables: `scope_learning_paths`, `scope_learning_path_units`, `scope_unit_items`

**File:** `20260320000001_create_learning_path_tables.sql:105-106, 126-127, 160-161`

**Current:**
```sql
CREATE POLICY "authenticated_select" ON scope_learning_paths
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "authenticated_select" ON scope_learning_path_units
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "authenticated_select" ON scope_unit_items
  FOR SELECT USING (auth.role() = 'authenticated');
```

**Fix:**
```sql
-- scope_learning_paths: scope to user's school
DROP POLICY IF EXISTS "authenticated_select" ON scope_learning_paths;
CREATE POLICY "school_select" ON scope_learning_paths
  FOR SELECT USING (school_id = get_user_school_id());

-- scope_learning_path_units: scope via parent's school
DROP POLICY IF EXISTS "authenticated_select" ON scope_learning_path_units;
CREATE POLICY "school_select" ON scope_learning_path_units
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM scope_learning_paths slp
      WHERE slp.id = scope_learning_path_units.scope_learning_path_id
      AND slp.school_id = get_user_school_id()
    )
  );

-- scope_unit_items: scope via grandparent's school
DROP POLICY IF EXISTS "authenticated_select" ON scope_unit_items;
CREATE POLICY "school_select" ON scope_unit_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM scope_learning_path_units slpu
      JOIN scope_learning_paths slp ON slp.id = slpu.scope_learning_path_id
      WHERE slpu.id = scope_unit_items.scope_lp_unit_id
      AND slp.school_id = get_user_school_id()
    )
  );
```

**Verification:** After applying, test that:
1. Student from School A cannot see School B's learning paths
2. `get_class_learning_path_units` RPC still works (SECURITY DEFINER, bypasses RLS)
3. Students can still see their own school's learning paths

---

## P1-HIGH — Data Integrity

### FIX-06: `user_node_completions.user_id` references `auth.users` instead of `profiles`

**Problem:** Every other user table references `profiles(id)`, but this one references `auth.users(id)`.
If a profile is deleted via admin without deleting the auth user (edge case), orphan rows remain.

**File:** `20260210000003_create_node_completions.sql:3`

**Fix:**
```sql
-- Drop the existing FK and add the correct one
ALTER TABLE user_node_completions
  DROP CONSTRAINT IF EXISTS user_node_completions_user_id_fkey;

ALTER TABLE user_node_completions
  ADD CONSTRAINT user_node_completions_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
```

---

### FIX-07: `learning_path_templates` policies use non-existent `'head_teacher'` role

**Problem:** The CHECK constraint on `profiles.role` allows `('student', 'teacher', 'head', 'admin')`,
but the RLS policies check for `'head_teacher'` which never matches. Result: `head` role users
cannot manage templates.

Affects: `learning_path_templates`, `learning_path_template_units`, `learning_path_template_items`

**File:** `20260320000001_create_learning_path_tables.sql:22, 40, 70`

**Fix:**
```sql
-- Fix all three tables
DROP POLICY IF EXISTS "admin_full_access" ON learning_path_templates;
CREATE POLICY "admin_full_access" ON learning_path_templates
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

DROP POLICY IF EXISTS "admin_full_access" ON learning_path_template_units;
CREATE POLICY "admin_full_access" ON learning_path_template_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

DROP POLICY IF EXISTS "admin_full_access" ON learning_path_template_items;
CREATE POLICY "admin_full_access" ON learning_path_template_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );
```

**Note:** Also fix the same issue on `scope_learning_paths`, `scope_learning_path_units`,
`scope_unit_items` admin policies (same `'head_teacher'` → `'head'` fix needed).

---

### FIX-08: `created_by` and `class_id` FKs default to RESTRICT

**Problem:** `learning_path_templates.created_by`, `scope_learning_paths.created_by`, and
`scope_learning_paths.class_id` have no ON DELETE clause, defaulting to RESTRICT. Deleting
a teacher/admin who created templates or a class with scope paths will fail unexpectedly.

**File:** `20260320000001_create_learning_path_tables.sql:10, 82-84`

**Fix:**
```sql
-- learning_path_templates.created_by → SET NULL on delete
ALTER TABLE learning_path_templates
  DROP CONSTRAINT IF EXISTS learning_path_templates_created_by_fkey;
ALTER TABLE learning_path_templates
  ADD CONSTRAINT learning_path_templates_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- scope_learning_paths.created_by → SET NULL on delete
ALTER TABLE scope_learning_paths
  DROP CONSTRAINT IF EXISTS scope_learning_paths_created_by_fkey;
ALTER TABLE scope_learning_paths
  ADD CONSTRAINT scope_learning_paths_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- scope_learning_paths.class_id → SET NULL on delete
ALTER TABLE scope_learning_paths
  DROP CONSTRAINT IF EXISTS scope_learning_paths_class_id_fkey;
ALTER TABLE scope_learning_paths
  ADD CONSTRAINT scope_learning_paths_class_id_fkey
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE SET NULL;
```

---

### FIX-09: `avatar_items` and `user_avatar_items` FKs default to RESTRICT

**Problem:** Deactivating/deleting an avatar category or item blocks the operation because child
rows exist. Should be SET NULL for category, CASCADE for user ownership.

**File:** `20260326000001_create_avatar_tables.sql:28, 42`

**Fix:**
```sql
-- avatar_items.category_id → SET NULL (keep item, just unlink category)
ALTER TABLE avatar_items
  DROP CONSTRAINT IF EXISTS avatar_items_category_id_fkey;
ALTER TABLE avatar_items
  ADD CONSTRAINT avatar_items_category_id_fkey
  FOREIGN KEY (category_id) REFERENCES avatar_item_categories(id) ON DELETE SET NULL;

-- Make category_id nullable first if not already
ALTER TABLE avatar_items ALTER COLUMN category_id DROP NOT NULL;

-- user_avatar_items.item_id → CASCADE (if item deleted, remove from inventory)
ALTER TABLE user_avatar_items
  DROP CONSTRAINT IF EXISTS user_avatar_items_item_id_fkey;
ALTER TABLE user_avatar_items
  ADD CONSTRAINT user_avatar_items_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES avatar_items(id) ON DELETE CASCADE;
```

---

### FIX-10: `profiles.coins` allows NULL

**Problem:** Column was added as `ADD COLUMN coins INTEGER DEFAULT 0` without NOT NULL.
While DEFAULT 0 covers new rows, a raw `UPDATE coins = NULL` would bypass the
`chk_coins_non_negative` CHECK (since `NULL >= 0` evaluates to NULL, not TRUE in PostgreSQL).

**Fix:**
```sql
-- Backfill any NULLs first (shouldn't exist, but safety)
UPDATE profiles SET coins = 0 WHERE coins IS NULL;

-- Add NOT NULL constraint
ALTER TABLE profiles ALTER COLUMN coins SET NOT NULL;
```

---

## P2-MEDIUM — Missing Indexes & Performance

### FIX-11: Missing indexes on FK columns

**Problem:** Several FK columns lack indexes, causing full table scans on JOIN queries.

**Fix:**
```sql
-- vocabulary_session_words.word_id — "find all sessions containing word X"
CREATE INDEX idx_vocab_session_words_word_id
  ON vocabulary_session_words(word_id);

-- book_quiz_results.quiz_id — "admin: all results for quiz X"
CREATE INDEX idx_book_quiz_results_quiz_id
  ON book_quiz_results(quiz_id);

-- daily_quest_completions.quest_id — "how many users completed quest X"
CREATE INDEX idx_quest_completions_quest_id
  ON daily_quest_completions(quest_id);

-- scope_learning_paths.template_id — "all scopes from template X"
CREATE INDEX idx_scope_lp_template_id
  ON scope_learning_paths(template_id)
  WHERE template_id IS NOT NULL;

-- user_avatar_items.item_id — "who owns item X"
CREATE INDEX idx_user_avatar_items_item_id
  ON user_avatar_items(item_id);
```

---

### FIX-12: N+1 correlated subqueries in `get_class_learning_path_units`

**Problem:** Per-row `SELECT ARRAY_AGG(...)` and `SELECT COUNT(*)` subqueries execute once per
`scope_unit_items` row. For a path with 30 items, that's 60+ extra queries.

**File:** `20260326000009_assignment_unit_type.sql:133-147`

**Current (problematic):**
```sql
CASE WHEN sui.word_list_id IS NOT NULL THEN
  (SELECT ARRAY_AGG(vw.word ORDER BY vw.word)
   FROM word_list_items wli
   JOIN vocabulary_words vw ON vw.id = wli.word_id
   WHERE wli.word_list_id = sui.word_list_id)
ELSE NULL END AS words,
CASE WHEN sui.book_id IS NOT NULL THEN
  (SELECT COUNT(*) FROM chapters ch WHERE ch.book_id = sui.book_id)
ELSE NULL END AS book_chapter_count
```

**Fix — use CTEs to pre-aggregate:**
```sql
CREATE OR REPLACE FUNCTION get_class_learning_path_units(p_class_id UUID)
RETURNS TABLE (...) -- same signature
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
BEGIN
  SELECT p.school_id, c.grade INTO v_school_id, v_grade
  FROM profiles p JOIN classes c ON c.id = p.class_id
  WHERE p.id = auth.uid();

  RETURN QUERY
  WITH word_list_words AS (
    SELECT wli.word_list_id, ARRAY_AGG(vw.word ORDER BY vw.word) AS words
    FROM word_list_items wli
    JOIN vocabulary_words vw ON vw.id = wli.word_id
    GROUP BY wli.word_list_id
  ),
  book_chapters AS (
    SELECT ch.book_id, COUNT(*) AS chapter_count
    FROM chapters ch
    GROUP BY ch.book_id
  )
  SELECT
    slp.id AS path_id,
    slp.name::VARCHAR AS path_name,
    vu.id AS unit_id,
    slpu.id AS scope_lp_unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    sui.item_type::VARCHAR,
    sui.id AS item_id,
    sui.sort_order AS item_sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    wlw.words,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    bc.chapter_count AS book_chapter_count
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  LEFT JOIN word_list_words wlw ON wlw.word_list_id = sui.word_list_id
  LEFT JOIN book_chapters bc ON bc.book_id = sui.book_id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = p_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;
```

---

### FIX-13: N+1 correlated subqueries in `get_unit_assignment_items`

**Problem:** Same N+1 issue — 5 correlated subqueries per item row.

**File:** `20260326000009_assignment_unit_type.sql:195-234`

**Fix — same CTE approach:**
```sql
CREATE OR REPLACE FUNCTION get_unit_assignment_items(
  p_scope_lp_unit_id UUID,
  p_student_id UUID
)
RETURNS TABLE (...) -- same signature
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF auth.uid() != p_student_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  WITH word_counts AS (
    SELECT wli.word_list_id, COUNT(*) AS cnt
    FROM word_list_items wli
    GROUP BY wli.word_list_id
  ),
  wl_completions AS (
    SELECT uwlp.word_list_id
    FROM user_word_list_progress uwlp
    WHERE uwlp.user_id = p_student_id AND uwlp.completed_at IS NOT NULL
  ),
  chapter_counts AS (
    SELECT ch.book_id, COUNT(*) AS total
    FROM chapters ch
    GROUP BY ch.book_id
  ),
  reading AS (
    SELECT rp.book_id,
           COALESCE(array_length(rp.completed_chapter_ids, 1), 0) AS completed
    FROM reading_progress rp
    WHERE rp.user_id = p_student_id
  )
  SELECT
    sui.item_type::VARCHAR,
    sui.sort_order,
    sui.word_list_id,
    wl.name::VARCHAR AS word_list_name,
    wc.cnt AS word_count,
    (wlc.word_list_id IS NOT NULL) AS is_word_list_completed,
    sui.book_id,
    b.title::VARCHAR AS book_title,
    cc.total AS total_chapters,
    r.completed AS completed_chapters,
    (r.completed >= cc.total) AS is_book_completed
  FROM scope_unit_items sui
  LEFT JOIN word_lists wl ON wl.id = sui.word_list_id
  LEFT JOIN books b ON b.id = sui.book_id
  LEFT JOIN word_counts wc ON wc.word_list_id = sui.word_list_id
  LEFT JOIN wl_completions wlc ON wlc.word_list_id = sui.word_list_id
  LEFT JOIN chapter_counts cc ON cc.book_id = sui.book_id
  LEFT JOIN reading r ON r.book_id = sui.book_id
  WHERE sui.scope_lp_unit_id = p_scope_lp_unit_id
  ORDER BY sui.sort_order;
END;
$$;
```

---

### FIX-14: Drop orphaned `daily_quest_pack_claims` table

**Problem:** Replaced by `daily_quest_bonus_claims` but never dropped. The old
`claim_daily_quest_pack` RPC is also orphaned.

**Fix:**
```sql
-- Drop old RPC first
DROP FUNCTION IF EXISTS claim_daily_quest_pack(UUID);

-- Drop old table
DROP TABLE IF EXISTS daily_quest_pack_claims;
```

**Pre-check:** Verify no Flutter code references `daily_quest_pack_claims`:
```bash
grep -r "daily_quest_pack_claims\|claim_daily_quest_pack\|claimDailyQuestPack" lib/
```

---

### FIX-15: `badges.condition_type = 'daily_login'` never evaluated

**Problem:** The CHECK constraint allows `'daily_login'` as a condition type, but
`check_and_award_badges` has no branch to evaluate it. Badges with this type can never be earned.

**Fix (Option A — implement the handler):**
```sql
-- In check_and_award_badges, add this branch inside the badge loop:
ELSIF v_badge.condition_type = 'daily_login' THEN
  IF (SELECT COUNT(DISTINCT login_date)
      FROM daily_logins
      WHERE user_id = p_user_id) >= v_badge.condition_value THEN
    v_earned := TRUE;
  END IF;
```

**Fix (Option B — remove unused type):**
If no `daily_login` badges exist in production, just remove from CHECK:
```sql
ALTER TABLE badges DROP CONSTRAINT IF EXISTS badges_condition_type_check;
ALTER TABLE badges ADD CONSTRAINT badges_condition_type_check
  CHECK (condition_type IN ('books_read', 'xp_earned', 'streak_days',
                            'words_mastered', 'quizzes_passed', 'cards_collected'));
```

---

### FIX-16: `xp_logs.source` and `coin_logs.source` lack CHECK constraint

**Problem:** Free-form `VARCHAR(50)` allows typos in source strings like
`'vocaulary_session'` instead of `'vocabulary_session'`, silently corrupting audit data.

**Fix:**
```sql
-- xp_logs: add CHECK with all known source values
ALTER TABLE xp_logs ADD CONSTRAINT chk_xp_source CHECK (
  source IN (
    'vocabulary_session', 'daily_review', 'badge', 'streak_milestone',
    'chapter_complete', 'inline_activity', 'book_quiz', 'daily_quest',
    'admin_adjustment'
  )
);

-- coin_logs: add CHECK with all known source values
ALTER TABLE coin_logs ADD CONSTRAINT chk_coin_source CHECK (
  source IN (
    'vocabulary_session', 'daily_review', 'badge', 'streak_milestone',
    'chapter_complete', 'inline_activity', 'book_quiz', 'daily_quest',
    'pack_purchase', 'streak_freeze', 'avatar_item', 'card_trade',
    'avatar_gender_change', 'admin_adjustment'
  )
);
```

**Pre-check:** Verify existing values match:
```sql
SELECT DISTINCT source FROM xp_logs ORDER BY source;
SELECT DISTINCT source FROM coin_logs ORDER BY source;
```

---

### FIX-17: `pack_purchases` INSERT policy `WITH CHECK (true)`

**Problem:** Any authenticated user can insert pack purchase records for other users.
Not as critical since this is a log table, but still pollutes audit trail.

**File:** `20260209000005_create_user_cards.sql:81-83`

**Fix:**
```sql
DROP POLICY IF EXISTS "System can insert pack purchases" ON pack_purchases;

-- No replacement needed — open_card_pack is SECURITY DEFINER and bypasses RLS.
```

---

### FIX-18: `system_settings` SELECT exposes all config to students

**Problem:** `USING (true)` lets students see internal values like streak freeze price,
XP multipliers, etc. Minor risk but enables informed exploit attempts.

**Fix:**
```sql
DROP POLICY IF EXISTS "Anyone can read system settings" ON system_settings;

-- Students can only read non-sensitive categories
CREATE POLICY "Users can read public settings" ON system_settings
  FOR SELECT USING (
    category IN ('feature_flags', 'notifications', 'ui')
    OR is_teacher_or_higher()
  );

-- Admins can manage all settings (should already exist, ensure it does)
```

**Note:** This requires categorizing settings. If all settings are currently needed client-side,
an alternative is to create a `public_system_settings` view that filters safe keys only.

---

### FIX-19: Weekly XP aggregation runs on every leaderboard load

**Problem:** `get_weekly_class_leaderboard` and similar functions aggregate `xp_logs` from
`week_start` to now on every call. As `xp_logs` grows, this gets slower.

**Fix (lightweight — summary column):**
```sql
-- Add weekly_xp column to profiles (like existing xp/coins pattern)
ALTER TABLE profiles ADD COLUMN weekly_xp INTEGER NOT NULL DEFAULT 0;

-- Reset weekly_xp in process_weekly_league_reset (already runs weekly)
-- Increment weekly_xp in award_xp_transaction alongside total xp
```

**Fix (heavier — materialized view):**
```sql
CREATE MATERIALIZED VIEW weekly_xp_summary AS
SELECT
  user_id,
  date_trunc('week', created_at AT TIME ZONE 'Europe/Istanbul')::DATE AS week_start,
  SUM(amount) AS weekly_xp
FROM xp_logs
GROUP BY user_id, week_start;

CREATE UNIQUE INDEX idx_weekly_xp_user_week
  ON weekly_xp_summary(user_id, week_start);

-- Refresh periodically or on demand
REFRESH MATERIALIZED VIEW CONCURRENTLY weekly_xp_summary;
```

**Recommendation:** The lightweight approach (weekly_xp column) is simpler and fits the existing
denormalization pattern. Reset it in the weekly league function.

---

## P3-LOW — Convention & Cleanup

### FIX-20: `activity_results` missing UNIQUE on `(user_id, activity_id, attempt_number)`

**Fix:**
```sql
CREATE UNIQUE INDEX idx_activity_results_unique_attempt
  ON activity_results(user_id, activity_id, attempt_number);
```

---

### FIX-21: `book_quiz_results` missing UNIQUE on `(user_id, quiz_id, attempt_number)`

**Fix:**
```sql
CREATE UNIQUE INDEX idx_quiz_results_unique_attempt
  ON book_quiz_results(user_id, quiz_id, attempt_number);
```

---

### FIX-22: `pack_purchases.cost = 0` conflates buy and open events

**Problem:** When opening from inventory, cost is logged as 0. The actual purchase was already
logged in `coin_logs`. The `pack_purchases` table name suggests purchase but records openings.

**Fix (rename for clarity):**
```sql
ALTER TABLE pack_purchases RENAME TO card_pack_openings;
ALTER TABLE card_pack_openings RENAME COLUMN cost TO coins_spent;

-- Update RPC references
-- Update DbTables constant in owlio_shared
```

**Note:** This is a naming improvement, not a bug. Low priority.

---

### FIX-23: `avatar_items.category_id` partial index excludes inactive items

**Current:** `CREATE INDEX idx_avatar_items_category ON avatar_items(category_id) WHERE is_active = true;`

**Fix:** Add a full index for admin queries:
```sql
CREATE INDEX idx_avatar_items_category_all ON avatar_items(category_id);
```

---

### FIX-24: Composite indexes for common filter patterns

**Fix:**
```sql
-- Books: often filtered by level + genre together
CREATE INDEX idx_books_level_genre ON books(level, genre);

-- Word lists: often filtered by level + category together
CREATE INDEX idx_word_lists_level_category ON word_lists(level, category);
```

---

### FIX-25: `reading_progress.completed_chapter_ids UUID[]` lacks FK validation

**Problem:** Array of UUIDs has no referential integrity check. If chapters are deleted,
stale IDs remain in the array.

**Fix (trigger-based validation):**
```sql
CREATE OR REPLACE FUNCTION validate_completed_chapter_ids()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.completed_chapter_ids IS NOT NULL AND array_length(NEW.completed_chapter_ids, 1) > 0 THEN
    IF EXISTS (
      SELECT 1 FROM unnest(NEW.completed_chapter_ids) AS cid
      WHERE NOT EXISTS (SELECT 1 FROM chapters WHERE id = cid)
    ) THEN
      RAISE EXCEPTION 'Invalid chapter ID in completed_chapter_ids';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_completed_chapters
  BEFORE INSERT OR UPDATE ON reading_progress
  FOR EACH ROW EXECUTE FUNCTION validate_completed_chapter_ids();
```

**Note:** This adds overhead per write. Alternative: accept the denormalization and handle
stale IDs in the application layer (current approach, works fine in practice).

---

### FIX-26: `user_card_stats.total_unique_cards` drift after trades

**Problem:** Only updated during `open_card_pack`. If `trade_duplicate_cards` removes all copies
of a card, the count doesn't decrement.

**Fix:** Update `trade_duplicate_cards` to recalculate:
```sql
-- At the end of trade_duplicate_cards, add:
UPDATE user_card_stats
SET total_unique_cards = (SELECT COUNT(*) FROM user_cards WHERE user_id = p_user_id),
    updated_at = NOW()
WHERE user_id = p_user_id;
```

---

### FIX-27: `process_weekly_league_reset` uses nested loops

**Problem:** Outer loop over classes, inner loop over students. O(classes * students) individual
queries.

**Fix sketch (set-based):**
```sql
-- Instead of looping, use a single INSERT ... SELECT with window functions:
INSERT INTO league_history (user_id, class_id, week_start, league_tier, rank, weekly_xp, result)
SELECT
  p.id,
  p.class_id,
  date_trunc('week', app_now())::DATE,
  p.league_tier,
  ROW_NUMBER() OVER (PARTITION BY p.class_id ORDER BY COALESCE(wx.xp, 0) DESC),
  COALESCE(wx.xp, 0),
  CASE
    WHEN ROW_NUMBER() OVER (...) <= promotion_cutoff THEN 'promoted'
    WHEN ROW_NUMBER() OVER (...) > demotion_cutoff THEN 'demoted'
    ELSE 'stayed'
  END
FROM profiles p
LEFT JOIN (
  SELECT user_id, SUM(amount) AS xp
  FROM xp_logs
  WHERE created_at >= date_trunc('week', app_now())
  GROUP BY user_id
) wx ON wx.user_id = p.id
WHERE p.role = 'student' AND p.class_id IS NOT NULL;
```

**Note:** The promotion/demotion thresholds depend on league tier, making full set-based
replacement complex. Consider a hybrid: one query to compute ranks, then batch UPDATE.

---

## Migration File Template

When implementing these fixes, create a single migration file:

```
supabase/migrations/YYYYMMDD000001_database_audit_fixes.sql
```

Or split into logical groups:
```
supabase/migrations/YYYYMMDD000001_security_rls_fixes.sql      -- FIX 01-05, 17
supabase/migrations/YYYYMMDD000002_fk_integrity_fixes.sql       -- FIX 06, 08-10
supabase/migrations/YYYYMMDD000003_rls_role_fixes.sql           -- FIX 07
supabase/migrations/YYYYMMDD000004_missing_indexes.sql          -- FIX 11, 20-21, 23-24
supabase/migrations/YYYYMMDD000005_rpc_performance.sql          -- FIX 12-13
supabase/migrations/YYYYMMDD000006_cleanup.sql                  -- FIX 14-16, 22, 25-26
```

**Always run `supabase db push --dry-run` before pushing any migration.**

---

## Quick Reference: What's Working Well

These patterns are professional-grade and should NOT be changed:

| Pattern | Where | Why It's Good |
|---------|-------|---------------|
| Atomic RPCs | `complete_vocabulary_session`, `complete_daily_review` | Single transaction: session + XP + streak + badges |
| FOR UPDATE row locks | All monetary RPCs | Race condition prevention |
| Idempotency indexes | `xp_logs`, `coin_logs` | Duplicate XP/coin prevention |
| Column-level REVOKE | `profiles.coins/unopened_packs/streak_freeze_count` | Defense-in-depth |
| Partial indexes | `vocabulary_progress`, `reading_progress`, `xp_logs` | Only index what matters |
| Counter-cache triggers | `books.chapter_count`, `word_lists.word_count` | Avoid COUNT(*) on reads |
| Controlled denormalization | `profiles.xp/coins/level` + audit tables | Fast reads, auditable writes |
| SECURITY DEFINER + auth guard | All financial RPCs | Bypass RLS safely with identity check |
| CHECK constraints | Roles, levels, non-negative balances | Schema-level validation |
| `safe_profiles` view | Profile visibility | PII protection between students |
