-- Fix: vocabulary_units only had SELECT policy, admins couldn't INSERT/UPDATE/DELETE
CREATE POLICY "admin_full_access" ON vocabulary_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );
