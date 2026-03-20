-- =============================================
-- LEARNING PATH TEMPLATES & SCOPE ASSIGNMENTS
-- =============================================

-- 1. Template definition
CREATE TABLE learning_path_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  description TEXT,
  created_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER update_learning_path_templates_updated_at
  BEFORE UPDATE ON learning_path_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE learning_path_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON learning_path_templates
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

-- 2. Template units (ordered)
CREATE TABLE learning_path_template_units (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES learning_path_templates(id) ON DELETE CASCADE,
  unit_id     UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  UNIQUE(template_id, unit_id)
);

CREATE INDEX idx_lp_template_units_template ON learning_path_template_units(template_id);

ALTER TABLE learning_path_template_units ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON learning_path_template_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

-- 3. Template items (word lists + books, interleaved)
CREATE TABLE learning_path_template_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_unit_id UUID NOT NULL REFERENCES learning_path_template_units(id) ON DELETE CASCADE,
  item_type        VARCHAR(20) NOT NULL CHECK (item_type IN ('word_list', 'book')),
  word_list_id     UUID REFERENCES word_lists(id) ON DELETE CASCADE,
  book_id          UUID REFERENCES books(id) ON DELETE CASCADE,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL)
  )
);

CREATE INDEX idx_lp_template_items_unit ON learning_path_template_items(template_unit_id);

CREATE UNIQUE INDEX idx_lp_template_items_word_list
  ON learning_path_template_items(template_unit_id, word_list_id)
  WHERE word_list_id IS NOT NULL;

CREATE UNIQUE INDEX idx_lp_template_items_book
  ON learning_path_template_items(template_unit_id, book_id)
  WHERE book_id IS NOT NULL;

ALTER TABLE learning_path_template_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON learning_path_template_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

-- 4. Scope learning path instance
CREATE TABLE scope_learning_paths (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(255) NOT NULL,
  template_id UUID REFERENCES learning_path_templates(id) ON DELETE SET NULL,
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  grade       INTEGER CHECK (grade BETWEEN 1 AND 12),
  class_id    UUID REFERENCES classes(id),
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_by  UUID REFERENCES profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (NOT (grade IS NOT NULL AND class_id IS NOT NULL))
);

CREATE TRIGGER update_scope_learning_paths_updated_at
  BEFORE UPDATE ON scope_learning_paths
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_scope_lp_school ON scope_learning_paths(school_id);
CREATE INDEX idx_scope_lp_school_grade ON scope_learning_paths(school_id, grade) WHERE grade IS NOT NULL;
CREATE INDEX idx_scope_lp_class ON scope_learning_paths(class_id) WHERE class_id IS NOT NULL;

ALTER TABLE scope_learning_paths ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON scope_learning_paths
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

CREATE POLICY "authenticated_select" ON scope_learning_paths
  FOR SELECT USING (auth.role() = 'authenticated');

-- 5. Scope learning path units (ordered)
CREATE TABLE scope_learning_path_units (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_learning_path_id UUID NOT NULL REFERENCES scope_learning_paths(id) ON DELETE CASCADE,
  unit_id                UUID NOT NULL REFERENCES vocabulary_units(id) ON DELETE CASCADE,
  sort_order             INTEGER NOT NULL DEFAULT 0,
  UNIQUE(scope_learning_path_id, unit_id)
);

CREATE INDEX idx_scope_lp_units_path ON scope_learning_path_units(scope_learning_path_id);

ALTER TABLE scope_learning_path_units ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON scope_learning_path_units
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

CREATE POLICY "authenticated_select" ON scope_learning_path_units
  FOR SELECT USING (auth.role() = 'authenticated');

-- 6. Scope unit items (word lists + books, interleaved)
CREATE TABLE scope_unit_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope_lp_unit_id UUID NOT NULL REFERENCES scope_learning_path_units(id) ON DELETE CASCADE,
  item_type        VARCHAR(20) NOT NULL CHECK (item_type IN ('word_list', 'book')),
  word_list_id     UUID REFERENCES word_lists(id) ON DELETE CASCADE,
  book_id          UUID REFERENCES books(id) ON DELETE CASCADE,
  sort_order       INTEGER NOT NULL DEFAULT 0,
  CHECK (
    (item_type = 'word_list' AND word_list_id IS NOT NULL AND book_id IS NULL) OR
    (item_type = 'book' AND book_id IS NOT NULL AND word_list_id IS NULL)
  )
);

CREATE INDEX idx_scope_unit_items_unit ON scope_unit_items(scope_lp_unit_id);

CREATE UNIQUE INDEX idx_scope_unit_items_word_list
  ON scope_unit_items(scope_lp_unit_id, word_list_id)
  WHERE word_list_id IS NOT NULL;

CREATE UNIQUE INDEX idx_scope_unit_items_book
  ON scope_unit_items(scope_lp_unit_id, book_id)
  WHERE book_id IS NOT NULL;

ALTER TABLE scope_unit_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON scope_unit_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head_teacher'))
  );

CREATE POLICY "authenticated_select" ON scope_unit_items
  FOR SELECT USING (auth.role() = 'authenticated');
