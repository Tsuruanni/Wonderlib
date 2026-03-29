# Active Node Indicator — Design Spec

## Problem

Students open the vocabulary hub and land at the top of the learning path every time. They have no quick way to see where they left off. The active node has a subtle glow, but there's no directional indicator or auto-scroll to guide the eye.

## Solution

Three changes to the learning path:

1. **Animated arrow icon** next to the active node, on the opposite side of the text label
2. **Auto-scroll** so the screen opens centered on the active node
3. **Ensure bounce animation works on all active node types** (vocabulary word list nodes + special nodes)

## Design Details

### 1. Arrow Indicator

**Position:** The arrow appears on the **opposite side** of the text label, pointing toward the node.

| Text position | Arrow position | Arrow icon direction |
|---------------|----------------|---------------------|
| Left of node  | Right of node  | Points left (◀ toward node) |
| Right of node | Left of node   | Points right (▶ toward node) |

**Icon:** `Icons.double_arrow_rounded`, mirrored via `Transform` for direction. Size 24px. Color: `AppColors.primary` with alpha 0.9.

**Animation:** Rhythmic horizontal translate toward the node:
- Offset: 0px → 6px toward node, repeating with reverse
- Duration: 900ms
- Curve: `Curves.easeInOut`
- Independent of the node's bounce animation (different rhythm creates visual interest)

**Placement:** Vertically centered with the node circle. Horizontally 12px gap from the node container edge.

**Visibility:** Only on the single active node (same condition as bounce: `isActive && !isLocked`).

### 2. Auto-Scroll to Active Node

**Behavior:** When the vocabulary hub screen opens, the scroll position starts **centered on the active node**. No scroll animation — the view is already at the right position on first frame.

**Implementation:**
- `LearningPath._buildPath` already accumulates a `y` variable as it lays out nodes. When the active node is found, record that `y` value.
- Expose active Y via a `StateProvider<double?>` (e.g. `activeNodeYProvider`) — `LearningPath` writes to it during build, `VocabularyHubScreen` reads it.
- `VocabularyHubScreen` creates a `ScrollController` with `initialScrollOffset` = `activeNodeY - (screenHeight / 2)`, clamped to `[0, maxScrollExtent]`.
- If no active node exists (all complete or empty path), scroll starts at top (offset 0).

### 3. Bounce Animation on Vocabulary Nodes

The bounce animation (1.0 → 1.08 scale, 1200ms, easeInOut, repeat reverse) already exists in `PathNode` code. Verify it fires correctly for the active word list node. If it's not working, the issue is likely that `_setupBounce()` isn't called when `isActive` is true on first build (check `initState` vs `didUpdateWidget` timing).

## Affected Files

| File | Change |
|------|--------|
| `path_node.dart` | Add arrow widget to the Row layout, with translate animation |
| `path_special_nodes.dart` | Add arrow to `_SpecialNodeCircle` Row layout (same logic) |
| `learning_path.dart` | Track active node Y position during `_buildPath`, expose it |
| `vocabulary_hub_screen.dart` | Add `ScrollController` with `initialScrollOffset` based on active Y |

## Out of Scope

- Arrow on non-active nodes
- Scroll animation (deliberate: instant positioning)
- Changes to existing glow or connector visuals
