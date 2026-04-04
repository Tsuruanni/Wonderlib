# Fullscreen Immersive Learning Path

**Date:** 2026-04-04
**Status:** Approved

## Summary

Add a fullscreen immersive mode to the learning path experience. When activated, the sidebar, right info panel, and navigation bars are completely removed, giving the student a distraction-free, map-only experience. The student can navigate units, open unit details, and launch vocabulary sessions — all within the fullscreen context.

## Motivation

The current learning path renders inside the shell layout (sidebar + right panel + navbar). On smaller screens or for focused study, students should be able to expand the map into a fullscreen experience where they can see and interact with all path nodes without UI chrome.

## Design

### Route Structure

Two new routes registered with `parentNavigatorKey: rootNavigatorKey` to bypass the shell entirely:

| Route | Screen | Purpose |
|-------|--------|---------|
| `/vocabulary/path/:pathId/fullscreen` | `FullscreenMapScreen` | Unit-level map, fullscreen |
| `/vocabulary/path/:pathId/fullscreen/unit/:unitIdx` | `FullscreenUnitDetailScreen` | Unit item nodes, fullscreen |

### Route Helpers (AppRoutes)

```dart
static String vocabularyPathFullscreen(String pathId) =>
    '/vocabulary/path/$pathId/fullscreen';
static String vocabularyPathFullscreenUnit(String pathId, int unitIdx) =>
    '/vocabulary/path/$pathId/fullscreen/unit/$unitIdx';
```

### Entry Point

**UnitMapScreen** — a round expand button positioned at top-right (Positioned overlay, same style as existing `_BackButton`):

- Icon: `Icons.open_in_full_rounded`
- White circle with shadow, 40x40
- On tap: `context.push(AppRoutes.vocabularyPathFullscreen(pathId))`

### FullscreenMapScreen

A `Scaffold` with no AppBar, no shell. Contents:

- **Background:** `AppColors.background`
- **Body:** `Stack` containing:
  1. `SingleChildScrollView` → reuses `UnitMapScreen`'s tile-building logic (`_buildTileMap` or `_buildSimpleUnitList`) to render unit nodes on `MapTile`
  2. **Minimize button** — top-right, `Positioned(top: 12, right: 12)`, same circular style as `_BackButton` but with `Icons.close_fullscreen_rounded` icon. On tap: `context.pop()`
- **Auto-scroll:** Same active-unit scroll logic from `UnitMapScreen`
- **Unit tap:** Navigates to `AppRoutes.vocabularyPathFullscreenUnit(pathId, unitIdx)`

### FullscreenUnitDetailScreen

A `Scaffold` with no AppBar, no shell. Contents:

- **Body:** `Stack` containing:
  1. `SingleChildScrollView` → reuses `UnitDetailScreen`'s tile-building logic (`_buildUnitTile`) to render item nodes on `MapTile`
  2. **Back button** — top-left, `Positioned(top: 12, left: 12)`, existing `_BackButton` style with `Icons.arrow_back_rounded`. On tap: `context.pop()` (returns to FullscreenMapScreen)
  3. **Minimize button** — top-right, `Positioned(top: 12, right: 12)`, same as FullscreenMapScreen. On tap: pops back to normal UnitMapScreen (pop until fullscreen routes are gone)
- **Auto-scroll:** Same active-node scroll logic from `UnitDetailScreen`
- **Node tap:** Opens popup card (existing PathNode behavior) → START navigates to existing `VocabularySessionScreen` route. When session completes and user pops back, they return to FullscreenUnitDetailScreen with updated state.

### Navigation Flow

```
UnitMapScreen (normal, in shell)
  → [expand button, top-right] → FullscreenMapScreen
      → [unit node tap] → FullscreenUnitDetailScreen
          → [word list node tap] → popup → START → VocabularySessionScreen
          → [book node tap] → popup → READ → BookDetailScreen
          → [back button, top-left] → FullscreenMapScreen
      → [minimize button, top-right] → pop back to UnitMapScreen
  → [minimize from unit detail, top-right] → pop all fullscreen routes, back to UnitMapScreen
```

### Widget Reuse

No changes to existing shared widgets:

| Widget | Reused As-Is |
|--------|-------------|
| `MapTile` | Yes — renders tile background + positioned nodes |
| `PathNode` | Yes — handles tap, popup, state styling |
| `StartBubble` | Yes — "START" / "YOU ARE HERE" indicator |
| `UnitDivider` | Yes — unit separator |

The fullscreen screens extract the build logic from `UnitMapScreen` and `UnitDetailScreen`. Any future changes to MapTile, PathNode, or tile themes automatically apply to both normal and fullscreen modes.

### Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `lib/presentation/screens/vocabulary/fullscreen_map_screen.dart` | **Create** | Fullscreen unit map |
| `lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart` | **Create** | Fullscreen unit detail |
| `lib/app/router.dart` | **Modify** | Add 2 routes with `parentNavigatorKey: rootNavigatorKey` |
| `lib/app/router.dart` (AppRoutes) | **Modify** | Add 2 route path helpers |
| `lib/presentation/screens/vocabulary/unit_map_screen.dart` | **Modify** | Add expand button overlay (top-right) |

### Edge Cases

- **Single path:** VocabularyHubScreen shows UnitMapScreen directly — expand button still works
- **No theme:** Falls back to `_buildSimpleUnitList` (card-based, no tile image) — fullscreen still works
- **Session completion:** Provider rebuilds on pop → node states update automatically
- **Mobile:** Bottom navbar already hidden (root navigator route). Expand button visible, minimize returns to shell.
- **ESC / Android back:** Standard `pop` behavior — works correctly with GoRouter

### Out of Scope

- Pinch-to-zoom / InteractiveViewer (can be added later)
- Dark/immersive theme for fullscreen (uses same AppColors.background)
- Landscape orientation lock
- Fullscreen entry from VocabularyHubScreen path selection (only from UnitMapScreen)
