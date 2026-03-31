-- ============================================
-- Tile Themes — configurable map tile visuals
-- ============================================

CREATE TABLE tile_themes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  height INT NOT NULL DEFAULT 1000,
  fallback_color_1 TEXT NOT NULL DEFAULT '#2E7D32',
  fallback_color_2 TEXT NOT NULL DEFAULT '#81C784',
  node_positions JSONB NOT NULL DEFAULT '[]',
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE tile_themes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON tile_themes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

CREATE POLICY "authenticated_read" ON tile_themes
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Seed 6 default themes
INSERT INTO tile_themes (name, height, fallback_color_1, fallback_color_2, node_positions, sort_order) VALUES
  ('Forest',   1000, '#2E7D32', '#81C784', '[{"x":0.50,"y":0.08},{"x":0.35,"y":0.22},{"x":0.58,"y":0.36},{"x":0.32,"y":0.50},{"x":0.55,"y":0.64},{"x":0.40,"y":0.78},{"x":0.50,"y":0.92}]', 0),
  ('Beach',    1000, '#0288D1', '#81D4FA', '[{"x":0.48,"y":0.08},{"x":0.62,"y":0.22},{"x":0.38,"y":0.36},{"x":0.55,"y":0.50},{"x":0.35,"y":0.64},{"x":0.52,"y":0.78},{"x":0.45,"y":0.92}]', 1),
  ('Mountain', 1000, '#546E7A', '#B0BEC5', '[{"x":0.50,"y":0.08},{"x":0.38,"y":0.22},{"x":0.60,"y":0.36},{"x":0.35,"y":0.50},{"x":0.58,"y":0.64},{"x":0.42,"y":0.78},{"x":0.50,"y":0.92}]', 2),
  ('Desert',   1000, '#E65100', '#FFCC80', '[{"x":0.52,"y":0.08},{"x":0.36,"y":0.22},{"x":0.56,"y":0.36},{"x":0.40,"y":0.50},{"x":0.60,"y":0.64},{"x":0.38,"y":0.78},{"x":0.48,"y":0.92}]', 3),
  ('Garden',   1000, '#C2185B', '#F48FB1', '[{"x":0.50,"y":0.08},{"x":0.40,"y":0.22},{"x":0.58,"y":0.36},{"x":0.35,"y":0.50},{"x":0.55,"y":0.64},{"x":0.45,"y":0.78},{"x":0.50,"y":0.92}]', 4),
  ('Winter',   1000, '#1565C0', '#BBDEFB', '[{"x":0.48,"y":0.08},{"x":0.60,"y":0.22},{"x":0.36,"y":0.36},{"x":0.58,"y":0.50},{"x":0.38,"y":0.64},{"x":0.52,"y":0.78},{"x":0.45,"y":0.92}]', 5);

-- Add tile_theme_id FK to vocabulary_units
ALTER TABLE vocabulary_units
  ADD COLUMN tile_theme_id UUID REFERENCES tile_themes(id) ON DELETE SET NULL;
