# Learning Path UI Redesign — Spec

## Overview

Replace the current programmatic learning path (absolute positioning, CustomPaint zigzag, 2000+ lines across 5 tightly-coupled files) with a tile-based map system inspired by Duolingo/Candy Crush level maps.

## Goals

- Clean, maintainable code (~600-800 lines total vs 2000+)
- Zero code duplication (current: sine offset in 3 places, bounce animation in 2)
- Easy to add new node types (add enum value + icon, done)
- Responsive by design (mobile crops edges, web shows full tile)
- Bug-resistant (no imperative Y accumulation, no 40+ magic numbers)

## Architecture

### Tile-Based Map System

**Background:** Pre-made illustrated map tile images (AI-generated). The path/road is part of the image. No programmatic path drawing.

**Nodes:** Flutter widgets positioned on top of the tile image using percentage-based coordinates.

**Layout:** Tiles stacked vertically in a `SingleChildScrollView`. Each unit gets one tile.

### Responsive Behavior

- Tile fixed width: **800px** (asset rendered at 1600px for retina)
- **Web (>=800px):** Full tile visible with decorations
- **Tablet (600-800px):** Slight edge cropping
- **Mobile (<600px):** Edges cropped, path centered — like looking through a window

```dart
ClipRect(
  child: OverflowBox(
    maxWidth: 800,
    child: Stack(
      children: [
        Image.asset(tileAsset, width: 800, fit: BoxFit.cover),
        // Nodes positioned here...
      ],
    ),
  ),
)
```

Shell integration: Learning Path route (`/vocabulary`) already has `isFullWidth` flag — no `ConstrainedBox` applied.

### File Structure

```
lib/presentation/widgets/learning_path/
├── learning_path.dart        # Orchestrator: reads provider, builds tile list
├── map_tile.dart             # Single tile: background image + positions nodes
├── path_node.dart            # Universal node widget (all types, all states)
├── node_progress_sheet.dart  # Bottom sheet for node details (words, mastery, actions)
├── unit_divider.dart         # Separator between units ("Unit 1: First Words")
├── tile_themes.dart          # Pure data: theme definitions + node positions + placeholder colors
└── start_bubble.dart         # Animated START label on active node
```

Legacy files renamed with `_legacy` suffix for rollback safety.

### Data Flow

```
learningPathProvider (existing, unchanged)
  ↓ List<PathUnitData>
LearningPath widget (orchestrator)
  ↓ for each unit → builds: [UnitDivider, MapTile, UnitDivider, MapTile, ...]
UnitDivider (standalone widget between tiles — NOT inside tile)
MapTile(theme, items)
  ↓ for each node slot
PathNode(type, state, label, onTap → opens NodeProgressSheet)
```

**Rules:**
- `PathNode` reads ZERO providers — all data passed as props
- `MapTile` only does positioning — no business logic
- `LearningPath` is the single orchestrator — reads providers, distributes to children
- `tile_themes.dart` is pure const data

## Node System

### Single Universal Widget

```dart
PathNode(
  type: NodeType.wordList,
  state: NodeState.active,
  label: "First Words",
  onTap: () => ...,
)
```

### Node Types (enum)

| Type | Icon | Color |
|------|------|-------|
| wordList | book | AppColors.secondary |
| book | auto_stories | AppColors.primary |
| game | extension_puzzle | AppColors.wasp |
| treasure | inventory_2 | AppColors.cardLegendary |
| review | refresh | AppColors.streakOrange |

Adding a new type: add enum value + icon + color. No widget code changes.

### Node States (enum)

| State | Visual |
|-------|--------|
| locked | Gray, 50% opacity, lock icon overlay |
| available | Full color, normal size |
| active | Full color, bounce animation, START bubble |
| completed | Full color, green check overlay |

### Node Size

- Circle: 64x64
- Label: below the node, max 120px wide, ellipsis overflow

## Tile Theme System

### Definition (tile_themes.dart)

```dart
class TileTheme {
  final String assetPath;
  final List<Offset> nodePositions; // percentage-based (0.0 - 1.0)

  final List<Color> fallbackColors; // gradient for placeholder mode

  const TileTheme({
    required this.assetPath,
    required this.nodePositions,
    required this.fallbackColors,
  });
}

const kTileThemes = [
  TileTheme(
    assetPath: 'assets/images/map_tiles/tile_forest.webp',
    nodePositions: [
      Offset(0.50, 0.08),
      Offset(0.35, 0.22),
      Offset(0.55, 0.36),
      Offset(0.30, 0.50),
      Offset(0.60, 0.64),
      Offset(0.45, 0.78),
      Offset(0.50, 0.92),
    ],
  ),
  // ... more themes
];
```

### Theme Cycling

Unit index determines theme: `kTileThemes[unitIndex % kTileThemes.length]`

### Slot Allocation

- Unit has N items, tile has M slots
- If N <= M: use first N slots
- If N > M: add a second tile of same theme, continue filling

### Tile Dimensions

- Asset: 1600x2000px (retina @2x)
- Render: 800x1000px
- Format: WebP for production, placeholder gradients for development

## Tile Asset Production

### AI Generation Prompt

```
Top-down 2D game level map tile, cute cartoon style,
winding dirt path going from top to bottom through a
[THEME] landscape, colorful and playful like Duolingo
or Candy Crush map, no characters, no UI elements, no
text, seamless top and bottom edges, mobile game style,
flat illustration, 800x1000 aspect ratio
```

### Themes (5-6, cycled for max 12 units)

1. Forest (green, trees, grass)
2. Beach (sand, sea, palms)
3. Mountain (snowy peaks, rocks)
4. Desert (sand dunes, cactus)
5. Garden (flowers, butterflies)
6. Winter (snow, pine trees, ice)

### Requirements

- Path width ~120-150px within the image
- Path entrance at top-center, exit at bottom-center (tiles connect seamlessly)
- Child-friendly, vibrant but not overwhelming colors
- Path area relatively simple (nodes will overlay)

## Animations

- **Active node bounce:** 1200ms duration, scale 1.0→1.08, infinite repeat
- **START bubble:** 800ms fade-in + slide-up on mount
- Both defined once in their respective widget files

## Node Tap Behavior

Tap behavior varies by node type — all handled via `onTap` callback passed from `LearningPath` orchestrator:

| Type | Tap Action |
|------|------------|
| wordList | Opens `NodeProgressSheet` (word list details, mastery, start button) |
| book | Navigates to book detail screen |
| game | Opens inline game completion flow |
| treasure | Claims treasure reward |
| review | Navigates to daily review session |

`NodeProgressSheet` lives in `node_progress_sheet.dart` — extracted from current `path_node.dart`'s inline bottom sheet. Receives all data as props (no provider reads).

## Placeholder Tiles (Development Mode)

Before real assets are ready, each theme renders as:
- `Container` with `LinearGradient` using theme-specific colors
- Subtle pattern overlay (dots or grid) to indicate tile boundaries
- Each `TileTheme` defines `fallbackColors: [Color, Color]` for this purpose

## Auto-Scroll

Existing behavior preserved: on data load, scroll to active node's Y position.

**Formula:** `scrollOffset = unitIndex * (tileHeight + dividerHeight) + slotIndex * (tileHeight / slotCount)`

Where:
- `tileHeight` = 1000px (rendered)
- `dividerHeight` = 60px
- `slotIndex` = active node's position within the tile
- `slotCount` = number of items in that unit

This is deterministic — no provider needed, computed from unit/item indices.

## Migration Plan

1. Rename existing files with `_legacy` suffix
2. Build new system with placeholder tile backgrounds
3. Wire up to existing `learningPathProvider` (unchanged)
4. Swap imports in `vocabulary_hub_screen.dart`
5. Generate and add real tile assets
6. Delete legacy files once stable
