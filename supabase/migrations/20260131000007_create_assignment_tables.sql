-- Migration 7: Assignment Tables
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- ASSIGNMENTS
-- =============================================
CREATE TABLE assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL
        CHECK (type IN ('book', 'vocabulary', 'mixed')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    content_config JSONB NOT NULL,
    -- book: {"bookId": "...", "chapterIds": [...]}
    -- vocabulary: {"wordListId": "..."}
    -- mixed: {"bookId": "...", "wordListId": "..."}
    settings JSONB DEFAULT '{}',
    start_date TIMESTAMPTZ NOT NULL,
    due_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE assignments IS 'Teacher-assigned work for students';

-- =============================================
-- ASSIGNMENT STUDENTS
-- =============================================
CREATE TABLE assignment_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'in_progress', 'completed', 'overdue')),
    score DECIMAL(5,2),
    progress DECIMAL(5,2) DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    UNIQUE(assignment_id, student_id)
);

COMMENT ON TABLE assignment_students IS 'Student progress on assignments';
