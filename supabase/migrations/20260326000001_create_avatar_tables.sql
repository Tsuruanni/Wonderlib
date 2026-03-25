-- =============================================
-- AVATAR CUSTOMIZATION TABLES
-- =============================================

-- 1. Avatar bases (6 animals)
CREATE TABLE avatar_bases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    image_url TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Avatar item categories (dynamic slots)
CREATE TABLE avatar_item_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    z_index INT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Avatar items (accessory catalog)
CREATE TABLE avatar_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES avatar_item_categories(id),
    name VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(150) NOT NULL,
    rarity VARCHAR(20) NOT NULL DEFAULT 'common'
        CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
    coin_price INT NOT NULL CHECK (coin_price >= 0),
    image_url TEXT NOT NULL,
    preview_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. User avatar items (ownership + equipped state)
CREATE TABLE user_avatar_items (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES avatar_items(id),
    is_equipped BOOLEAN DEFAULT false,
    purchased_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, item_id)
);

-- 5. Add avatar columns to profiles
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS avatar_base_id UUID REFERENCES avatar_bases(id),
    ADD COLUMN IF NOT EXISTS avatar_equipped_cache JSONB;

-- 6. Indexes
CREATE INDEX idx_avatar_items_category ON avatar_items(category_id) WHERE is_active = true;
CREATE INDEX idx_user_avatar_items_user ON user_avatar_items(user_id);
CREATE INDEX idx_user_avatar_items_equipped ON user_avatar_items(user_id) WHERE is_equipped = true;

-- =============================================
-- RLS POLICIES
-- =============================================

ALTER TABLE avatar_bases ENABLE ROW LEVEL SECURITY;
ALTER TABLE avatar_item_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE avatar_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_avatar_items ENABLE ROW LEVEL SECURITY;

-- Catalog tables: read-only for all authenticated
CREATE POLICY "avatar_bases_select" ON avatar_bases
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "avatar_item_categories_select" ON avatar_item_categories
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "avatar_items_select" ON avatar_items
    FOR SELECT TO authenticated USING (is_active = true);

-- User items: SELECT own only. INSERT/UPDATE via SECURITY DEFINER RPCs only.
CREATE POLICY "user_avatar_items_select_own" ON user_avatar_items
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- =============================================
-- SEED: Base animals
-- =============================================
INSERT INTO avatar_bases (name, display_name, image_url, sort_order) VALUES
    ('owl',    'Wise Owl',     'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/owl.png', 1),
    ('fox',    'Clever Fox',   'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/fox.png', 2),
    ('bear',   'Brave Bear',   'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/bear.png', 3),
    ('rabbit', 'Quick Rabbit', 'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/rabbit.png', 4),
    ('cat',    'Curious Cat',  'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/cat.png', 5),
    ('wolf',   'Noble Wolf',   'https://wqkxjjakysuabjcotvim.supabase.co/storage/v1/object/public/avatars/bases/wolf.png', 6);

-- SEED: Item categories
INSERT INTO avatar_item_categories (name, display_name, z_index, sort_order) VALUES
    ('background', 'Background', 0,  1),
    ('body',       'Body',       10, 2),
    ('face',       'Face',       20, 3),
    ('head',       'Head',       30, 4),
    ('hand',       'Hand',       40, 5);
