-- =============================================
-- FIX: Card System RLS Hardening
-- Problem: "System can manage" policies use USING(true) allowing
-- any authenticated user to directly INSERT/UPDATE/DELETE any user's cards.
-- The open_card_pack() SECURITY DEFINER function bypasses RLS entirely,
-- so these permissive policies are unnecessary and create a security hole.
-- =============================================

-- Drop overly permissive "system" policies
DROP POLICY IF EXISTS "System can manage user cards" ON user_cards;
DROP POLICY IF EXISTS "System can insert pack purchases" ON pack_purchases;
DROP POLICY IF EXISTS "System can manage card stats" ON user_card_stats;

-- user_cards: users can only modify own cards
CREATE POLICY "Users can manage own cards"
  ON user_cards FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- pack_purchases: users can only insert own purchases
CREATE POLICY "Users can insert own pack purchases"
  ON pack_purchases FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- user_card_stats: users can only modify own stats
CREATE POLICY "Users can manage own card stats"
  ON user_card_stats FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
