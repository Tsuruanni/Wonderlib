-- =============================================
-- Database Audit Phase 1: Zero-Risk Fixes
--
-- Reference: docs/database-audit-fixes.md
-- Scope: P0 security RLS, P1 FK integrity, P2 missing indexes
-- Risk: Zero — all writes go through SECURITY DEFINER RPCs
-- =============================================


-- =============================================================================
-- SECTION 1: SECURITY — Drop overly permissive RLS policies (P0)
-- =============================================================================

-- FIX-01: user_cards — FOR ALL USING (true) lets any user modify any user's cards
-- Safe: all writes go through open_card_pack / trade_duplicate_cards (SECURITY DEFINER)
DROP POLICY IF EXISTS "System can manage user cards" ON user_cards;

-- FIX-02: user_card_stats — FOR ALL USING (true) lets any user modify pity counter
-- Safe: only open_card_pack (SECURITY DEFINER) writes to this table
DROP POLICY IF EXISTS "System can manage card stats" ON user_card_stats;

-- FIX-03: xp_logs — WITH CHECK (true) lets any user insert XP entries for others
-- Safe: all XP logging goes through award_xp_transaction (SECURITY DEFINER)
DROP POLICY IF EXISTS "System can log XP" ON xp_logs;

-- FIX-17: pack_purchases — WITH CHECK (true) lets any user insert fake purchase records
-- Safe: only open_card_pack (SECURITY DEFINER) writes to this table
DROP POLICY IF EXISTS "System can insert pack purchases" ON pack_purchases;


-- =============================================================================
-- SECTION 2: SECURITY — Fix cross-school data leak on scope tables (P0)
-- =============================================================================

-- FIX-05: scope_learning_paths — USING (auth.role() = 'authenticated') exposes
-- ALL schools' learning paths to ALL authenticated users.
-- Safe: Flutter never queries these tables directly, only via SECURITY DEFINER RPCs.

-- scope_learning_paths: scope SELECT to user's own school
DROP POLICY IF EXISTS "authenticated_select" ON scope_learning_paths;
CREATE POLICY "school_select" ON scope_learning_paths
  FOR SELECT USING (school_id = get_user_school_id());

-- scope_learning_path_units: scope via parent's school_id
DROP POLICY IF EXISTS "authenticated_select" ON scope_learning_path_units;
CREATE POLICY "school_select" ON scope_learning_path_units
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM scope_learning_paths slp
      WHERE slp.id = scope_learning_path_units.scope_learning_path_id
        AND slp.school_id = get_user_school_id()
    )
  );

-- scope_unit_items: scope via grandparent's school_id
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


-- =============================================================================
-- SECTION 3: Fix 'head_teacher' → 'head' on scope table admin policies (P1)
-- Template tables were already fixed in 20260327100001, scope tables were not.
-- =============================================================================

-- FIX-07 (remainder): scope_learning_paths admin policy
DROP POLICY IF EXISTS "admin_full_access" ON scope_learning_paths;
CREATE POLICY "admin_full_access" ON scope_learning_paths
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

-- scope_learning_path_units admin policy
DROP POLICY IF EXISTS "admin_full_access" ON scope_learning_path_units;
CREATE POLICY "admin_full_access" ON scope_learning_path_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

-- scope_unit_items admin policy
DROP POLICY IF EXISTS "admin_full_access" ON scope_unit_items;
CREATE POLICY "admin_full_access" ON scope_unit_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );


-- =============================================================================
-- SECTION 4: FK integrity fixes (P1)
-- =============================================================================

-- FIX-06: user_node_completions references auth.users instead of profiles
-- Every other user table references profiles(id). This should too.
ALTER TABLE user_node_completions
  DROP CONSTRAINT IF EXISTS user_node_completions_user_id_fkey;
ALTER TABLE user_node_completions
  ADD CONSTRAINT user_node_completions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- FIX-08: created_by FKs default to RESTRICT — should SET NULL
-- (scope_learning_paths.class_id already fixed to CASCADE in 20260327100001)
ALTER TABLE learning_path_templates
  DROP CONSTRAINT IF EXISTS learning_path_templates_created_by_fkey;
ALTER TABLE learning_path_templates
  ADD CONSTRAINT learning_path_templates_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE scope_learning_paths
  DROP CONSTRAINT IF EXISTS scope_learning_paths_created_by_fkey;
ALTER TABLE scope_learning_paths
  ADD CONSTRAINT scope_learning_paths_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- FIX-09: user_avatar_items.item_id defaults to RESTRICT — should CASCADE
-- If an avatar item is hard-deleted, remove it from user inventories
ALTER TABLE user_avatar_items
  DROP CONSTRAINT IF EXISTS user_avatar_items_item_id_fkey;
ALTER TABLE user_avatar_items
  ADD CONSTRAINT user_avatar_items_item_id_fkey
    FOREIGN KEY (item_id) REFERENCES avatar_items(id) ON DELETE CASCADE;

-- FIX-10: profiles.coins allows NULL (added without NOT NULL)
-- Backfill safety net, then enforce
UPDATE profiles SET coins = 0 WHERE coins IS NULL;
ALTER TABLE profiles ALTER COLUMN coins SET NOT NULL;


-- =============================================================================
-- SECTION 5: Missing indexes (P2)
-- (scope_learning_paths.template_id already indexed in 20260327100001)
-- =============================================================================

-- FIX-11a: vocabulary_session_words.word_id — unindexed FK
CREATE INDEX IF NOT EXISTS idx_vocab_session_words_word_id
  ON vocabulary_session_words(word_id);

-- FIX-11b: book_quiz_results.quiz_id — admin needs "all results for quiz X"
CREATE INDEX IF NOT EXISTS idx_book_quiz_results_quiz_id
  ON book_quiz_results(quiz_id);

-- FIX-11c: daily_quest_completions.quest_id — "how many completed quest X today"
CREATE INDEX IF NOT EXISTS idx_quest_completions_quest_id
  ON daily_quest_completions(quest_id);

-- FIX-11d: user_avatar_items.item_id — "who owns item X"
CREATE INDEX IF NOT EXISTS idx_user_avatar_items_item_id
  ON user_avatar_items(item_id);
