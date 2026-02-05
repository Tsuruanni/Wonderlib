-- Migration: Add created_at to assignment_students table
-- This column tracks when a student was assigned to an assignment

ALTER TABLE assignment_students
ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();

-- Update existing rows to have created_at based on the assignment's created_at
UPDATE assignment_students AS astu
SET created_at = a.created_at
FROM assignments a
WHERE astu.assignment_id = a.id
AND astu.created_at IS NULL;
