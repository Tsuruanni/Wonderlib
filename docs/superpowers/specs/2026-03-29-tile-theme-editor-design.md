# Tile Theme Editor — Design Spec

**Date:** 2026-03-29
**Status:** Approved
**Goal:** Admin panel'den tile temalarını (yükseklik, gradient renkleri, node pozisyonları) düzenleyebilmek ve her üniteye tema atayabilmek.

---

## Database

### New Table: `tile_themes`

```sql
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

-- RLS: admin/head full access, authenticated read
ALTER TABLE tile_themes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_full_access" ON tile_themes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'head'))
  );

CREATE POLICY "authenticated_read" ON tile_themes
  FOR SELECT USING (auth.uid() IS NOT NULL);
```

**`node_positions` format:**
```json
[
  {"x": 0.50, "y": 0.08},
  {"x": 0.35, "y": 0.22},
  {"x": 0.58, "y": 0.36}
]
```

Each entry is a percentage (0.0–1.0) of the tile's width/height. Array length is dynamic — admin adds/removes positions freely.

### Alter Table: `vocabulary_units`

```sql
ALTER TABLE vocabulary_units
  ADD COLUMN tile_theme_id UUID REFERENCES tile_themes(id) ON DELETE SET NULL;
```

Nullable — if no theme is assigned, app falls back to hardcoded `tileThemeForUnit()` cycling.

### Seed Data

The 6 existing hardcoded themes are inserted as seed rows so existing behavior is preserved:

```sql
INSERT INTO tile_themes (name, height, fallback_color_1, fallback_color_2, node_positions, sort_order) VALUES
  ('Forest',   1000, '#2E7D32', '#81C784', '[{"x":0.50,"y":0.08},{"x":0.35,"y":0.22},{"x":0.58,"y":0.36},{"x":0.32,"y":0.50},{"x":0.55,"y":0.64},{"x":0.40,"y":0.78},{"x":0.50,"y":0.92}]', 0),
  ('Beach',    1000, '#0288D1', '#81D4FA', '[{"x":0.48,"y":0.08},{"x":0.62,"y":0.22},{"x":0.38,"y":0.36},{"x":0.55,"y":0.50},{"x":0.35,"y":0.64},{"x":0.52,"y":0.78},{"x":0.45,"y":0.92}]', 1),
  ('Mountain', 1000, '#546E7A', '#B0BEC5', '[{"x":0.50,"y":0.08},{"x":0.38,"y":0.22},{"x":0.60,"y":0.36},{"x":0.35,"y":0.50},{"x":0.58,"y":0.64},{"x":0.42,"y":0.78},{"x":0.50,"y":0.92}]', 2),
  ('Desert',   1000, '#E65100', '#FFCC80', '[{"x":0.52,"y":0.08},{"x":0.36,"y":0.22},{"x":0.56,"y":0.36},{"x":0.40,"y":0.50},{"x":0.60,"y":0.64},{"x":0.38,"y":0.78},{"x":0.48,"y":0.92}]', 3),
  ('Garden',   1000, '#C2185B', '#F48FB1', '[{"x":0.50,"y":0.08},{"x":0.40,"y":0.22},{"x":0.58,"y":0.36},{"x":0.35,"y":0.50},{"x":0.55,"y":0.64},{"x":0.45,"y":0.78},{"x":0.50,"y":0.92}]', 4),
  ('Winter',   1000, '#1565C0', '#BBDEFB', '[{"x":0.48,"y":0.08},{"x":0.60,"y":0.22},{"x":0.36,"y":0.36},{"x":0.58,"y":0.50},{"x":0.38,"y":0.64},{"x":0.52,"y":0.78},{"x":0.45,"y":0.92}]', 5);
```

---

## Domain Layer (Main App)

### Entity: `TileThemeEntity`

```
TileThemeEntity:
  id: String
  name: String
  height: int (default 1000, stored as INT in DB, cast to double in widgets)
  fallbackColor1: String (hex)
  fallbackColor2: String (hex)
  nodePositions: List<Offset> (percentage coordinates)
  sortOrder: int
  isActive: bool
```

### Model: `TileThemeModel`

- `TileThemeModel.fromJson(Map<String, dynamic>)` — parses DB row
- `toEntity()` → `TileThemeEntity`
- `node_positions` JSONB parsed to `List<Offset>`

### Repository

- `TileThemeRepository.getTileThemes()` → `Future<Either<Failure, List<TileThemeEntity>>>`
- Implementation: `SELECT * FROM tile_themes WHERE is_active = true ORDER BY sort_order`

### UseCase

- `GetTileThemesUseCase` — returns all active themes

---

## Presentation Layer (Main App)

### Provider: `tileThemesProvider`

```dart
final tileThemesProvider = FutureProvider<List<TileThemeEntity>>((ref) async {
  // Fetch from DB, fallback to hardcoded kTileThemes on failure
});
```

### Theme Resolution (in LearningPathView orchestrator)

Theme resolution stays in the orchestrator (not a separate provider) because it needs the unit index for fallback cycling:

```
for each unit at unitIdx:
  if unit.unit.tileThemeId != null:
    find matching theme from tileThemesProvider list
  else:
    use tileThemeForUnit(unitIdx) hardcoded fallback
```

No dedicated `tileThemeForUnitProvider` needed — the orchestrator already has both the unit and its index.

### Changes to `tile_themes.dart`

- `kTileHeight` removed as global constant — each tile uses its theme's height
- `kTileWidth` stays global (800px)
- `kDividerHeight` stays global (60px)
- `TileTheme` class gains a `height` field (double)
- Hardcoded `kTileThemes` list stays as fallback

### Changes to `LearningPathView`

- Reads `tileThemesProvider` to get DB themes
- Each unit resolves its theme via `unit.unit.tileThemeId` → DB theme, or fallback cycling
- `MapTile` receives theme with per-tile height

### Changes to `MapTile`

- Uses `theme.height` instead of `kTileHeight` for SizedBox and node positioning

### Changes to `activeNodeYProvider`

- Accumulates Y using each unit's actual theme height (not a fixed constant)
- Y for unit N = sum of (dividerHeight + theme[i].height) for i in 0..<N, plus dividerHeight + nodePosition.dy * theme[N].height

### Changes to `VocabularyUnit` entity

- Add `tileThemeId: String?` field
- Update `VocabularyUnitModel.fromJson` to parse `tile_theme_id`

---

## Admin Panel

All UI text in Turkish (per project convention for admin panel).

### Route: `/tiles`

**Tema Listesi Screen** — DataTable with columns:
- Renk preview (small gradient rectangle)
- Tema Adı
- Yükseklik (px)
- Node Sayısı
- Sıralama
- Düzenle butonu

### Route: `/tiles/new` and `/tiles/:id`

**Tema Editörü Screen** — Split layout:

**Sol panel (form):**
- Tema Adı: TextFormField
- Yükseklik: Slider (300–1500px) + numeric input
- Gradient Renk 1: Hex color picker (same pattern as unit editor)
- Gradient Renk 2: Hex color picker
- Node Pozisyonları: Dynamic list
  - Each row: "Node N" label + X slider (0–100%) + Y slider (0–100%) + delete button
  - "Node Ekle" button at bottom
- Sıralama: Numeric input
- Aktif: Switch

**Sağ panel (live preview):**
- Scaled-down tile preview (fit within ~300px wide area)
- Gradient background using the two colors
- Colored circles at each node position
- Node circles numbered (1, 2, 3...)
- Preview updates instantly as sliders change

### Unit Edit Screen Change

Add a dropdown to existing unit edit form:
- Label: "Tile Teması"
- Options: All active tile themes by name (+ "Otomatik" option for null/fallback)
- Saves `tile_theme_id` to `vocabulary_units`

### Provider Pattern (Admin)

```dart
final tileThemesAdminProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await supabase.from('tile_themes').select().order('sort_order');
});

final tileThemeDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  return await supabase.from('tile_themes').select().eq('id', id).maybeSingle();
});
```

CRUD follows existing admin pattern: direct Supabase calls, provider invalidation on save.

---

## Fallback Strategy

- If `tileThemesProvider` fails (network error, empty table): use hardcoded `kTileThemes`
- If a unit's `tile_theme_id` points to a deleted/inactive theme: fall back to cycling
- If a unit has fewer items than the theme has node positions: extra positions ignored
- If a unit has more items than node positions: extra items not rendered (same as current behavior)

---

## Out of Scope

- Tile background image upload (placeholder gradients only for now)
- Drag-and-drop node positioning in admin (sliders only)
- Per-theme tile width (stays global 800px)
