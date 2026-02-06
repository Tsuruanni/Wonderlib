-- =============================================
-- VOCABULARY UNITS (Duolingo-style path grouping)
-- =============================================

CREATE TABLE vocabulary_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    color VARCHAR(7),
    icon VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE vocabulary_units ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vocabulary_units_select" ON vocabulary_units
    FOR SELECT USING (true);

CREATE INDEX idx_vocabulary_units_sort_order ON vocabulary_units(sort_order);

-- =============================================
-- ADD UNIT FIELDS TO WORD_LISTS
-- =============================================

ALTER TABLE word_lists
    ADD COLUMN unit_id UUID REFERENCES vocabulary_units(id) ON DELETE SET NULL,
    ADD COLUMN order_in_unit INTEGER DEFAULT 0;

CREATE INDEX idx_word_lists_unit_order ON word_lists(unit_id, order_in_unit)
    WHERE unit_id IS NOT NULL;
