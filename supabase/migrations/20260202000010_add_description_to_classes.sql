-- Add description column to classes table
-- Required by get_classes_with_stats RPC function and teacher repository

ALTER TABLE classes ADD COLUMN description TEXT;

COMMENT ON COLUMN classes.description IS 'Optional description for the class';
