-- Migration 8: RLS Policies
-- ReadEng (Wonderlib) Database Schema

-- =============================================
-- ENABLE RLS ON ALL TABLES
-- =============================================
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE inline_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocabulary_words ENABLE ROW LEVEL SECURITY;
ALTER TABLE chapter_vocabulary ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_list_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE reading_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE inline_activity_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE vocabulary_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignment_students ENABLE ROW LEVEL SECURITY;

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Get current user's school ID
CREATE OR REPLACE FUNCTION get_user_school_id()
RETURNS UUID AS $$
    SELECT school_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
    SELECT EXISTS(SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Check if user is teacher or higher
CREATE OR REPLACE FUNCTION is_teacher_or_higher()
RETURNS BOOLEAN AS $$
    SELECT EXISTS(SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('teacher', 'head', 'admin'));
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- =============================================
-- SCHOOL POLICIES
-- =============================================
CREATE POLICY "Users can view their own school"
    ON schools FOR SELECT
    USING (id = get_user_school_id() OR is_admin());

CREATE POLICY "Public can view schools by code"
    ON schools FOR SELECT
    USING (true);  -- Allow school code validation during signup

CREATE POLICY "Admins can manage schools"
    ON schools FOR ALL
    USING (is_admin());

-- =============================================
-- CLASS POLICIES
-- =============================================
CREATE POLICY "Users can view classes in their school"
    ON classes FOR SELECT
    USING (school_id = get_user_school_id());

CREATE POLICY "Teachers can manage classes in their school"
    ON classes FOR ALL
    USING (
        school_id = get_user_school_id()
        AND is_teacher_or_higher()
    );

-- =============================================
-- PROFILE POLICIES
-- =============================================
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "Users can view profiles in their school"
    ON profiles FOR SELECT
    USING (school_id = get_user_school_id());

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (id = auth.uid());

CREATE POLICY "Allow profile creation on signup"
    ON profiles FOR INSERT
    WITH CHECK (id = auth.uid());

-- =============================================
-- CONTENT POLICIES (books, chapters, activities)
-- =============================================
CREATE POLICY "Anyone can read published books"
    ON books FOR SELECT
    USING (status = 'published');

CREATE POLICY "Admins can manage all books"
    ON books FOR ALL
    USING (is_admin());

CREATE POLICY "Anyone can read chapters of published books"
    ON chapters FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM books
            WHERE books.id = chapters.book_id
            AND books.status = 'published'
        )
    );

CREATE POLICY "Admins can manage chapters"
    ON chapters FOR ALL
    USING (is_admin());

CREATE POLICY "Anyone can read activities of published books"
    ON activities FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM chapters c
            JOIN books b ON c.book_id = b.id
            WHERE c.id = activities.chapter_id
            AND b.status = 'published'
        )
    );

CREATE POLICY "Admins can manage activities"
    ON activities FOR ALL
    USING (is_admin());

CREATE POLICY "Anyone can read inline activities"
    ON inline_activities FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM chapters c
            JOIN books b ON c.book_id = b.id
            WHERE c.id = inline_activities.chapter_id
            AND b.status = 'published'
        )
    );

CREATE POLICY "Admins can manage inline activities"
    ON inline_activities FOR ALL
    USING (is_admin());

-- =============================================
-- VOCABULARY POLICIES
-- =============================================
CREATE POLICY "Anyone can read vocabulary words"
    ON vocabulary_words FOR SELECT
    USING (true);

CREATE POLICY "Admins can manage vocabulary"
    ON vocabulary_words FOR ALL
    USING (is_admin());

CREATE POLICY "Anyone can read chapter vocabulary"
    ON chapter_vocabulary FOR SELECT
    USING (true);

CREATE POLICY "Anyone can read word lists"
    ON word_lists FOR SELECT
    USING (true);

CREATE POLICY "Admins can manage word lists"
    ON word_lists FOR ALL
    USING (is_admin());

CREATE POLICY "Anyone can read word list items"
    ON word_list_items FOR SELECT
    USING (true);

CREATE POLICY "Admins can manage word list items"
    ON word_list_items FOR ALL
    USING (is_admin());

-- =============================================
-- USER PROGRESS POLICIES
-- =============================================
CREATE POLICY "Users can manage own reading progress"
    ON reading_progress FOR ALL
    USING (user_id = auth.uid());

CREATE POLICY "Teachers can view student reading progress"
    ON reading_progress FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = reading_progress.user_id
            AND p.school_id = get_user_school_id()
            AND is_teacher_or_higher()
        )
    );

CREATE POLICY "Users can manage own activity results"
    ON activity_results FOR ALL
    USING (user_id = auth.uid());

CREATE POLICY "Teachers can view student activity results"
    ON activity_results FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = activity_results.user_id
            AND p.school_id = get_user_school_id()
            AND is_teacher_or_higher()
        )
    );

CREATE POLICY "Users can manage own inline activity results"
    ON inline_activity_results FOR ALL
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage own vocabulary progress"
    ON vocabulary_progress FOR ALL
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage own word list progress"
    ON user_word_list_progress FOR ALL
    USING (user_id = auth.uid());

-- =============================================
-- GAMIFICATION POLICIES
-- =============================================
CREATE POLICY "Anyone can read active badges"
    ON badges FOR SELECT
    USING (is_active = true);

CREATE POLICY "Admins can manage badges"
    ON badges FOR ALL
    USING (is_admin());

CREATE POLICY "Users can view own badges"
    ON user_badges FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "System can award badges"
    ON user_badges FOR INSERT
    WITH CHECK (true);  -- Controlled via Edge Functions

CREATE POLICY "Users can view own XP logs"
    ON xp_logs FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "System can log XP"
    ON xp_logs FOR INSERT
    WITH CHECK (true);  -- Controlled via Edge Functions

-- =============================================
-- ASSIGNMENT POLICIES
-- =============================================
CREATE POLICY "Teachers can manage own assignments"
    ON assignments FOR ALL
    USING (
        teacher_id = auth.uid()
        OR is_admin()
    );

CREATE POLICY "Teachers can view school assignments"
    ON assignments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.id = assignments.teacher_id
            AND p.school_id = get_user_school_id()
        )
        AND is_teacher_or_higher()
    );

CREATE POLICY "Students can view assigned assignments"
    ON assignments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM assignment_students
            WHERE assignment_id = assignments.id
            AND student_id = auth.uid()
        )
    );

CREATE POLICY "Teachers can manage assignment students"
    ON assignment_students FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM assignments
            WHERE assignments.id = assignment_students.assignment_id
            AND (assignments.teacher_id = auth.uid() OR is_admin())
        )
    );

CREATE POLICY "Students can view and update own assignment progress"
    ON assignment_students FOR SELECT
    USING (student_id = auth.uid());

CREATE POLICY "Students can update own assignment progress"
    ON assignment_students FOR UPDATE
    USING (student_id = auth.uid());
