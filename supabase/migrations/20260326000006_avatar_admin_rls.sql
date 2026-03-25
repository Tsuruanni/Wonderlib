-- =============================================
-- ADMIN MANAGEMENT POLICIES FOR AVATAR TABLES
-- Uses existing can_manage_content() helper
-- =============================================

-- avatar_bases: admins/teachers can manage
CREATE POLICY "admins_manage_avatar_bases" ON avatar_bases
    FOR ALL TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());

-- avatar_item_categories: admins/teachers can manage
CREATE POLICY "admins_manage_avatar_item_categories" ON avatar_item_categories
    FOR ALL TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());

-- avatar_items: admins/teachers can manage
CREATE POLICY "admins_manage_avatar_items" ON avatar_items
    FOR ALL TO authenticated
    USING (can_manage_content())
    WITH CHECK (can_manage_content());
