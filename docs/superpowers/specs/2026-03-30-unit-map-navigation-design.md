# Unit Map Navigation — Design Spec

**Date:** 2026-03-30
**Status:** Approved
**Goal:** Vocabulary hub'ı 3 katmanlı navigasyona dönüştürmek: path seçimi → ünite haritası (tile-based) → ünite detay (mevcut tile). Her learning path'in ve her ünitenin kendi tile teması olabilir.

---

## Navigation Flow

```
Vocabulary Hub
  ├─ 1 learning path → skip to Unit Map directly
  └─ 2+ learning paths → Path Selection List
                            └─ tap → Unit Map Screen
                                       └─ tap → Unit Detail Screen (existing tile)
```

- **1 path shortcut**: If user has exactly 1 learning path, vocabulary hub renders the Unit Map directly (no path selection). Back button goes to home.
- **2+ paths**: Vocabulary hub shows path selection cards. Tapping a path pushes to Unit Map. Back returns to path selection.

---

## Page 1: Path Selection (only when 2+ paths)

Simple card list (NOT tile-based). Each card shows:
- **Path name** (e.g., "MEB CYD", "Ek Okuma")
- **Unit count** (e.g., "8 ünite")
- **Completion progress** — fraction or percentage of completed units
- **Lock state** — if unit_gate is true and no units are accessible, card appears locked

Design: Vertical list of tappable cards, similar to Duolingo course selection. No tile background.

---

## Page 2: Unit Map Screen (new — tile-based)

Each learning path has its own `tile_theme_id`. The theme provides a background image + node positions for the units.

Each unit is rendered as a node on the tile:
- **Unit icon** (emoji from vocabulary_units)
- **Unit name**
- **Node state**: locked / available / active / completed (same `NodeState` enum as item nodes)
- **Active unit** gets the START bubble animation
- **Completed unit** gets green check overlay

### Unit lock logic
- If `unit_gate` is true on the learning path: units are sequential — next unit unlocks only when previous is complete
- If `unit_gate` is false: all units are available
- A unit is "complete" when `PathUnitData.isAllComplete` returns true

### Theme resolution
- If `scope_learning_paths.tile_theme_id` is set → use that theme from DB
- Else → hardcoded fallback (single default gradient)

### Node count mismatch
- Theme may have more node positions than units → extra positions ignored
- Theme may have fewer node positions than units → overflow units rendered in a simple list below the tile (edge case, admin should configure enough positions)

### Auto-scroll
- Scroll to the active unit on screen open (same pattern as existing activeNodeYProvider)

---

## Page 3: Unit Detail Screen (existing tile — isolated)

The existing `MapTile` + `LearningPathView` logic, but filtered to a **single unit**. Currently `LearningPathView` renders all units in a Column. The change:

- New `UnitDetailScreen` receives `pathId` + `unitIdx` (zero-based index within the path's unit list)
- Reads from `learningPathProvider`, filters to the specific unit
- Renders a single `MapTile` with that unit's items + that unit's tile theme
- Same node types: word list, book, game, treasure, daily review
- Same interactions: tap word list → progress sheet or detail, tap book → book detail, etc.
- Back button returns to Unit Map

---

## Database Changes

### Add `tile_theme_id` to learning path tables

```sql
ALTER TABLE scope_learning_paths
  ADD COLUMN tile_theme_id UUID REFERENCES tile_themes(id) ON DELETE SET NULL;

ALTER TABLE learning_path_templates
  ADD COLUMN tile_theme_id UUID REFERENCES tile_themes(id) ON DELETE SET NULL;
```

### Update RPC

`get_user_learning_paths` must return `slp.tile_theme_id` so the app can resolve the path-level theme.

Add to RETURNS TABLE:
```sql
lp_tile_theme_id UUID
```

Add to SELECT:
```sql
slp.tile_theme_id AS lp_tile_theme_id
```

---

## Domain Layer Changes

### LearningPath entity
Add field: `tileThemeId: String?`

### LearningPathModel
Parse `lp_tile_theme_id` from RPC rows → `LearningPath.tileThemeId`

### No new entities needed
Unit map reuses existing `PathUnitData` and `TileTheme` structures.

---

## Presentation Layer Changes

### New: `VocabularyHubScreen` (rewrite)

Current behavior: renders all units from all paths in one scrollable column.

New behavior:
- Watch `learningPathProvider`
- If 1 path: render `UnitMapView` inline (no push, acts as the hub)
- If 2+ paths: render `_PathSelectionList`

### New: `UnitMapView` widget

Tile-based map showing units as nodes. Reuses `MapTile` pattern:
- Receives `LearningPath` + `List<PathUnitData>` for that path
- Resolves path-level tile theme
- Positions unit nodes on the tile
- Each node tappable → push to `UnitDetailScreen`

### New: `UnitDetailScreen`

- Route: `/vocabulary/path/:pathId/unit/:unitIdx`
- Reads `learningPathProvider`, finds the specific path and unit
- Renders single unit's tile (existing `MapTile` + item nodes)
- AppBar with unit name, back button

### Modified: `LearningPathView`

No longer the main entry point. Becomes a helper that renders items for a single unit (used by `UnitDetailScreen`).

### Modified: Router

Add new routes:
```
/vocabulary/path/:pathId              → UnitMapScreen
/vocabulary/path/:pathId/unit/:unitIdx → UnitDetailScreen
```

### Modified: `activeNodeYProvider`

No longer needed for the full page scroll. Each screen has its own simpler scroll logic:
- Unit Map: scroll to active unit
- Unit Detail: scroll to active item within the unit

---

## Admin Changes

### Template Editor
Add tile theme dropdown at the **path level** (not just unit level). This sets the theme for the unit map background.

Label: "Harita Teması" — controls how units are displayed on the map.

### Assignment Editor
Same — add path-level tile theme dropdown.

### Save/Load
- Template save: include `tile_theme_id` on template row
- Assignment save: include `tile_theme_id` on scope_learning_paths row
- Load: fetch `tile_theme_id` from both tables

---

## Fallback Behavior

- No path-level theme assigned → simple gradient background for unit map
- No unit-level theme assigned → hardcoded cycling (existing `tileThemeForUnit`)
- Path has 0 units → empty state message
- Learning path provider error → error state with retry

---

## Out of Scope

- Path selection page is NOT tile-based (simple cards)
- No drag-and-drop for unit ordering (admin handles this in template editor)
- No transition animations between pages (standard push/pop)
- No offline caching changes
