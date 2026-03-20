-- Drop old RPC functions
DROP FUNCTION IF EXISTS get_assigned_vocabulary_units(UUID);
DROP FUNCTION IF EXISTS get_user_unit_books(UUID);

-- Drop old tables (CASCADE drops RLS policies, indexes, triggers)
DROP TABLE IF EXISTS unit_book_assignments CASCADE;
DROP TABLE IF EXISTS unit_curriculum_assignments CASCADE;
