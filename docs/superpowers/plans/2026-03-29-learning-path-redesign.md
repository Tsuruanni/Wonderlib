# Learning Path UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current 2000+ line learning path UI with a clean tile-based map system (~700 lines) that is responsive, maintainable, and visually inspired by Duolingo/Candy Crush level maps.

**Architecture:** Pre-made map tile images as backgrounds, Flutter widgets as interactive nodes positioned via percentage coordinates. Single orchestrator reads existing `learningPathProvider` and distributes data to pure-prop child widgets. No CustomPaint, no imperative Y accumulation, no duplicate positioning logic.

**Tech Stack:** Flutter, Riverpod, existing `learningPathProvider` (unchanged), WebP tile assets (placeholder gradients during dev)

**Spec:** `docs/superpowers/specs/2026-03-29-learning-path-redesign.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/presentation/widgets/learning_path/tile_themes.dart` | Create | Pure const data: tile themes, node positions, colors |
| `lib/presentation/widgets/learning_path/path_node.dart` | Create | Universal node widget (all types, all states) |
| `lib/presentation/widgets/learning_path/start_bubble.dart` | Create | Animated START bubble for active node |
| `lib/presentation/widgets/learning_path/map_tile.dart` | Create | Single tile: background + positioned nodes |
| `lib/presentation/widgets/learning_path/unit_divider.dart` | Create | Unit separator banner between tiles |
| `lib/presentation/widgets/learning_path/node_progress_sheet.dart` | Create | Bottom sheet for word list node details |
| `lib/presentation/widgets/learning_path/learning_path.dart` | Create | Orchestrator: provider → tiles → nodes |
| `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` | Modify | Swap old LearningPath import for new one |
| `lib/presentation/widgets/vocabulary/learning_path.dart` | Rename | → `learning_path_legacy.dart` |
| `lib/presentation/widgets/vocabulary/path_node.dart` | Rename | → `path_node_legacy.dart` |
| `lib/presentation/widgets/vocabulary/path_painters.dart` | Rename | → `path_painters_legacy.dart` |
| `lib/presentation/widgets/vocabulary/path_row.dart` | Rename | → `path_row_legacy.dart` |
| `lib/presentation/widgets/vocabulary/path_special_nodes.dart` | Rename | → `path_special_nodes_legacy.dart` |

---

### Task 1: Rename legacy files

**Files:**
- Rename: `lib/presentation/widgets/vocabulary/learning_path.dart` → `learning_path_legacy.dart`
- Rename: `lib/presentation/widgets/vocabulary/path_node.dart` → `path_node_legacy.dart`
- Rename: `lib/presentation/widgets/vocabulary/path_painters.dart` → `path_painters_legacy.dart`
- Rename: `lib/presentation/widgets/vocabulary/path_row.dart` → `path_row_legacy.dart`
- Rename: `lib/presentation/widgets/vocabulary/path_special_nodes.dart` → `path_special_nodes_legacy.dart`
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` (update imports)

- [ ] **Step 1: Rename the 5 legacy files**

```bash
cd /Users/wonderelt/Desktop/Owlio
mv lib/presentation/widgets/vocabulary/learning_path.dart lib/presentation/widgets/vocabulary/learning_path_legacy.dart
mv lib/presentation/widgets/vocabulary/path_node.dart lib/presentation/widgets/vocabulary/path_node_legacy.dart
mv lib/presentation/widgets/vocabulary/path_painters.dart lib/presentation/widgets/vocabulary/path_painters_legacy.dart
mv lib/presentation/widgets/vocabulary/path_row.dart lib/presentation/widgets/vocabulary/path_row_legacy.dart
mv lib/presentation/widgets/vocabulary/path_special_nodes.dart lib/presentation/widgets/vocabulary/path_special_nodes_legacy.dart
```

- [ ] **Step 2: Update imports in legacy files**

In `learning_path_legacy.dart`, update internal imports:
```dart
import 'path_painters_legacy.dart';
import 'path_row_legacy.dart';
import 'path_special_nodes_legacy.dart';
```

In `path_special_nodes_legacy.dart`, update:
```dart
import 'path_node_legacy.dart';
```

In `path_row_legacy.dart`, update:
```dart
import 'path_node_legacy.dart';
```

- [ ] **Step 3: Update vocabulary_hub_screen.dart import**

In `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`, change:
```dart
// Old:
import '../../widgets/vocabulary/learning_path.dart';
// New:
import '../../widgets/vocabulary/learning_path_legacy.dart';
```

- [ ] **Step 4: Verify build**

```bash
dart analyze lib/
```

Expected: No new errors (only pre-existing infos).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename learning path files to _legacy for safe migration"
```

---

### Task 2: Create tile_themes.dart

**Files:**
- Create: `lib/presentation/widgets/learning_path/tile_themes.dart`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p lib/presentation/widgets/learning_path
```

- [ ] **Step 2: Write tile_themes.dart**

```dart
import 'package:flutter/material.dart';

/// A map tile theme with background asset and node positions.
class TileTheme {
  const TileTheme({
    required this.name,
    required this.assetPath,
    required this.nodePositions,
    required this.fallbackColors,
  });

  /// Theme display name (for debugging).
  final String name;

  /// Asset path for the background image.
  final String assetPath;

  /// Node positions as percentages (0.0–1.0) of tile width/height.
  /// Index 0 is the topmost node, last is the bottommost.
  final List<Offset> nodePositions;

  /// Gradient colors for placeholder mode (before real assets exist).
  final List<Color> fallbackColors;
}

/// Tile render dimensions (logical pixels).
const kTileWidth = 800.0;
const kTileHeight = 1000.0;

/// Height of the unit divider widget between tiles.
const kDividerHeight = 60.0;

/// All available tile themes. Units cycle through these.
const kTileThemes = <TileTheme>[
  TileTheme(
    name: 'Forest',
    assetPath: 'assets/images/map_tiles/tile_forest.webp',
    nodePositions: [
      Offset(0.50, 0.08),
      Offset(0.35, 0.22),
      Offset(0.58, 0.36),
      Offset(0.32, 0.50),
      Offset(0.55, 0.64),
      Offset(0.40, 0.78),
      Offset(0.50, 0.92),
    ],
    fallbackColors: [Color(0xFF2E7D32), Color(0xFF81C784)],
  ),
  TileTheme(
    name: 'Beach',
    assetPath: 'assets/images/map_tiles/tile_beach.webp',
    nodePositions: [
      Offset(0.48, 0.08),
      Offset(0.62, 0.22),
      Offset(0.38, 0.36),
      Offset(0.55, 0.50),
      Offset(0.35, 0.64),
      Offset(0.52, 0.78),
      Offset(0.45, 0.92),
    ],
    fallbackColors: [Color(0xFF0288D1), Color(0xFF81D4FA)],
  ),
  TileTheme(
    name: 'Mountain',
    assetPath: 'assets/images/map_tiles/tile_mountain.webp',
    nodePositions: [
      Offset(0.50, 0.08),
      Offset(0.38, 0.22),
      Offset(0.60, 0.36),
      Offset(0.35, 0.50),
      Offset(0.58, 0.64),
      Offset(0.42, 0.78),
      Offset(0.50, 0.92),
    ],
    fallbackColors: [Color(0xFF546E7A), Color(0xFFB0BEC5)],
  ),
  TileTheme(
    name: 'Desert',
    assetPath: 'assets/images/map_tiles/tile_desert.webp',
    nodePositions: [
      Offset(0.52, 0.08),
      Offset(0.36, 0.22),
      Offset(0.56, 0.36),
      Offset(0.40, 0.50),
      Offset(0.60, 0.64),
      Offset(0.38, 0.78),
      Offset(0.48, 0.92),
    ],
    fallbackColors: [Color(0xFFE65100), Color(0xFFFFCC80)],
  ),
  TileTheme(
    name: 'Garden',
    assetPath: 'assets/images/map_tiles/tile_garden.webp',
    nodePositions: [
      Offset(0.50, 0.08),
      Offset(0.40, 0.22),
      Offset(0.58, 0.36),
      Offset(0.35, 0.50),
      Offset(0.55, 0.64),
      Offset(0.45, 0.78),
      Offset(0.50, 0.92),
    ],
    fallbackColors: [Color(0xFFC2185B), Color(0xFFF48FB1)],
  ),
  TileTheme(
    name: 'Winter',
    assetPath: 'assets/images/map_tiles/tile_winter.webp',
    nodePositions: [
      Offset(0.48, 0.08),
      Offset(0.60, 0.22),
      Offset(0.36, 0.36),
      Offset(0.58, 0.50),
      Offset(0.38, 0.64),
      Offset(0.52, 0.78),
      Offset(0.45, 0.92),
    ],
    fallbackColors: [Color(0xFF1565C0), Color(0xFFBBDEFB)],
  ),
];

/// Returns the theme for a given unit index (cycles through themes).
TileTheme tileThemeForUnit(int unitIndex) {
  return kTileThemes[unitIndex % kTileThemes.length];
}
```

- [ ] **Step 3: Verify**

```bash
dart analyze lib/presentation/widgets/learning_path/tile_themes.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/learning_path/tile_themes.dart
git commit -m "feat: add tile theme definitions for learning path redesign"
```

---

### Task 3: Create path_node.dart

**Files:**
- Create: `lib/presentation/widgets/learning_path/path_node.dart`

- [ ] **Step 1: Write path_node.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Node types on the learning path.
enum NodeType {
  wordList(Icons.menu_book_rounded, AppColors.secondary, Color(0xFF1899D6)),
  book(Icons.auto_stories_rounded, Color(0xFF1565C0), Color(0xFFE3F2FD)),
  game(Icons.sports_esports_rounded, Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
  treasure(Icons.card_giftcard_rounded, AppColors.cardLegendary, Color(0xFFFFF8E1)),
  review(Icons.style_rounded, Color(0xFFE65100), Color(0xFFFFF3E0));

  const NodeType(this.icon, this.color, this.bgColor);
  final IconData icon;
  final Color color;
  final Color bgColor;
}

/// Visual state of a node.
enum NodeState { locked, available, active, completed }

/// Universal node widget for the learning path.
/// Renders all node types and states. Receives all data as props — no providers.
class PathNode extends StatelessWidget {
  const PathNode({
    super.key,
    required this.type,
    required this.state,
    this.label,
    this.onTap,
    this.starCount = 0,
  });

  final NodeType type;
  final NodeState state;
  final String? label;
  final VoidCallback? onTap;
  final int starCount;

  static const _size = 64.0;

  @override
  Widget build(BuildContext context) {
    final isLocked = state == NodeState.locked;
    final isCompleted = state == NodeState.completed;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Node circle
            _NodeCircle(
              type: type,
              state: state,
              size: _size,
            ),
            // Star row (only for word lists with progress)
            if (type == NodeType.wordList && starCount > 0 && !isLocked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _StarRow(count: starCount, color: type.color),
              ),
            // Label
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isLocked
                        ? AppColors.neutralText
                        : isCompleted
                            ? AppColors.primary
                            : AppColors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The circular node icon.
class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.type,
    required this.state,
    required this.size,
  });

  final NodeType type;
  final NodeState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isLocked = state == NodeState.locked;
    final isCompleted = state == NodeState.completed;

    final bgColor = isLocked ? AppColors.neutral : type.bgColor;
    final iconColor = isLocked ? AppColors.neutralText : type.color;
    final borderColor = isLocked
        ? AppColors.neutral
        : isCompleted
            ? AppColors.primary
            : type.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            isLocked ? Icons.lock_rounded : type.icon,
            color: iconColor,
            size: size * 0.45,
          ),
          // Completed check overlay
          if (isCompleted)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Row of 1-3 stars below a word list node.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: filled ? color : AppColors.neutral,
        );
      }),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze lib/presentation/widgets/learning_path/path_node.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/learning_path/path_node.dart
git commit -m "feat: add universal PathNode widget for learning path"
```

---

### Task 4: Create start_bubble.dart

**Files:**
- Create: `lib/presentation/widgets/learning_path/start_bubble.dart`

- [ ] **Step 1: Write start_bubble.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Animated START bubble shown above the active node.
class StartBubble extends StatefulWidget {
  const StartBubble({super.key});

  @override
  State<StartBubble> createState() => _StartBubbleState();
}

class _StartBubbleState extends State<StartBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _bounce = Tween(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounce.value),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neutral, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neutral.withValues(alpha: 0.5),
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              'START',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 1,
              ),
            ),
          ),
          // Triangle pointer
          CustomPaint(
            size: const Size(16, 8),
            painter: _TrianglePainter(color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 2: Fix AnimatedBuilder → AnimatedBuilder**

Note: Flutter uses `AnimatedBuilder`, not `AnimatedBuilder`. Verify the class name is correct:

```bash
dart analyze lib/presentation/widgets/learning_path/start_bubble.dart
```

If `AnimatedBuilder` throws an error, it should be `AnimatedBuilder` — which is the correct Flutter class name. Both are the same.

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/learning_path/start_bubble.dart
git commit -m "feat: add animated StartBubble for active learning path node"
```

---

### Task 5: Create map_tile.dart

**Files:**
- Create: `lib/presentation/widgets/learning_path/map_tile.dart`

- [ ] **Step 1: Write map_tile.dart**

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'path_node.dart';
import 'start_bubble.dart';
import 'tile_themes.dart';

/// Data for a single node to be placed on a map tile.
class MapTileNodeData {
  const MapTileNodeData({
    required this.type,
    required this.state,
    this.label,
    this.onTap,
    this.starCount = 0,
  });

  final NodeType type;
  final NodeState state;
  final String? label;
  final VoidCallback? onTap;
  final int starCount;
}

/// A single map tile: background image + positioned nodes.
/// No business logic — only layout.
class MapTile extends StatelessWidget {
  const MapTile({
    super.key,
    required this.theme,
    required this.nodes,
  });

  final TileTheme theme;
  final List<MapTileNodeData> nodes;

  @override
  Widget build(BuildContext context) {
    final hasAsset = _assetExists(theme.assetPath);

    return ClipRect(
      child: SizedBox(
        height: kTileHeight,
        child: OverflowBox(
          maxWidth: kTileWidth,
          minWidth: kTileWidth,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Background
              Positioned.fill(
                child: hasAsset
                    ? Image.asset(
                        theme.assetPath,
                        width: kTileWidth,
                        height: kTileHeight,
                        fit: BoxFit.cover,
                      )
                    : _PlaceholderBackground(colors: theme.fallbackColors),
              ),
              // Nodes
              for (int i = 0; i < nodes.length; i++)
                if (i < theme.nodePositions.length)
                  _PositionedNode(
                    position: theme.nodePositions[i],
                    data: nodes[i],
                  ),
            ],
          ),
        ),
      ),
    );
  }

  bool _assetExists(String path) {
    // In Flutter, asset existence can't be checked synchronously.
    // Use placeholder mode by checking a flag or try-catch in Image.
    // For now, always use placeholder until real assets are added.
    // TODO: Switch to true when assets are ready.
    return false;
  }
}

/// A node positioned by percentage coordinates within the tile.
class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.position,
    required this.data,
  });

  final Offset position;
  final MapTileNodeData data;

  @override
  Widget build(BuildContext context) {
    final left = position.dx * kTileWidth - 70; // center 140px wide node
    final top = position.dy * kTileHeight - 40; // approximate vertical center

    return Positioned(
      left: left,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // START bubble above active node
          if (data.state == NodeState.active) ...[
            const StartBubble(),
            const SizedBox(height: 4),
          ],
          PathNode(
            type: data.type,
            state: data.state,
            label: data.label,
            onTap: data.onTap,
            starCount: data.starCount,
          ),
        ],
      ),
    );
  }
}

/// Gradient placeholder for when tile assets aren't ready.
class _PlaceholderBackground extends StatelessWidget {
  const _PlaceholderBackground({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _DotPatternPainter(),
      ),
    );
  }
}

/// Subtle dot pattern to indicate tile boundaries during development.
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 2: Remove unused dart:io import**

The `_assetExists` method doesn't need `dart:io`. Remove the import:

```dart
// Remove this line:
import 'dart:io';
```

- [ ] **Step 3: Verify**

```bash
dart analyze lib/presentation/widgets/learning_path/map_tile.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/widgets/learning_path/map_tile.dart
git commit -m "feat: add MapTile widget with placeholder backgrounds"
```

---

### Task 6: Create unit_divider.dart

**Files:**
- Create: `lib/presentation/widgets/learning_path/unit_divider.dart`

- [ ] **Step 1: Write unit_divider.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import 'tile_themes.dart';

/// Separator between map tiles showing unit name.
/// Rendered as a standalone widget between tiles (not inside a tile).
class UnitDivider extends StatelessWidget {
  const UnitDivider({
    super.key,
    required this.unitIndex,
    required this.unitName,
    this.unitIcon,
    this.isLocked = false,
  });

  final int unitIndex;
  final String unitName;
  final String? unitIcon;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kDividerHeight,
      child: OverflowBox(
        maxWidth: kTileWidth,
        minWidth: kTileWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              const Expanded(child: Divider(color: AppColors.neutral, thickness: 2)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${unitIcon ?? ''} UNIT ${unitIndex + 1}  $unitName'.trim(),
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isLocked ? AppColors.neutralText : AppColors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.neutral, thickness: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze lib/presentation/widgets/learning_path/unit_divider.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/learning_path/unit_divider.dart
git commit -m "feat: add UnitDivider for learning path tile separation"
```

---

### Task 7: Create node_progress_sheet.dart

**Files:**
- Create: `lib/presentation/widgets/learning_path/node_progress_sheet.dart`

- [ ] **Step 1: Write node_progress_sheet.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Data needed to display the word list progress bottom sheet.
class NodeProgressData {
  const NodeProgressData({
    required this.name,
    required this.totalSessions,
    this.bestAccuracy,
    this.bestScore,
    required this.starCount,
    required this.unitColor,
  });

  final String name;
  final int totalSessions;
  final double? bestAccuracy;
  final int? bestScore;
  final int starCount;
  final Color unitColor;
}

/// Shows a bottom sheet with word list progress details.
/// All data passed as props — no provider reads.
void showNodeProgressSheet(
  BuildContext context, {
  required NodeProgressData data,
  required VoidCallback onPractice,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _ProgressSheetContent(
      data: data,
      onPractice: onPractice,
    ),
  );
}

class _ProgressSheetContent extends StatelessWidget {
  const _ProgressSheetContent({
    required this.data,
    required this.onPractice,
  });

  final NodeProgressData data;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.neutral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Text(
            data.name,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < data.starCount;
              return Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 32,
                color: filled ? data.unitColor : AppColors.neutral,
              );
            }),
          ),
          const SizedBox(height: 16),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatColumn(
                  icon: Icons.repeat_rounded,
                  value: '${data.totalSessions}',
                  label: 'Sessions',
                ),
                _StatColumn(
                  icon: Icons.star_rounded,
                  value: data.bestAccuracy != null
                      ? '${data.bestAccuracy!.toInt()}%'
                      : '--',
                  label: 'Best',
                ),
                _StatColumn(
                  icon: Icons.bolt_rounded,
                  value: data.bestScore != null ? '${data.bestScore}' : '--',
                  label: 'Top Coins',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Practice button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPractice();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: data.unitColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'PRACTICE',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.neutralText, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze lib/presentation/widgets/learning_path/node_progress_sheet.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/learning_path/node_progress_sheet.dart
git commit -m "feat: add node progress bottom sheet for learning path"
```

---

### Task 8: Create learning_path.dart (orchestrator)

**Files:**
- Create: `lib/presentation/widgets/learning_path/learning_path.dart`

- [ ] **Step 1: Write learning_path.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../utils/ui_helpers.dart';
import 'map_tile.dart';
import 'node_progress_sheet.dart';
import 'path_node.dart';
import 'tile_themes.dart';
import 'unit_divider.dart';

/// Orchestrator widget for the tile-based learning path.
/// Reads from learningPathProvider, builds tiles with positioned nodes.
class LearningPathView extends ConsumerWidget {
  const LearningPathView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathDataAsync = ref.watch(learningPathProvider);

    return pathDataAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Could not load learning path',
          style: GoogleFonts.nunito(color: AppColors.neutralText),
          textAlign: TextAlign.center,
        ),
      ),
      data: (pathUnits) {
        if (pathUnits.isEmpty) {
          return _EmptyState();
        }
        return _buildTiles(context, ref, pathUnits);
      },
    );
  }

  Widget _buildTiles(BuildContext context, WidgetRef ref, List<PathUnitData> units) {
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    final star3 = settings?.starRating3 ?? 90;
    final star2 = settings?.starRating2 ?? 70;
    final star1 = settings?.starRating1 ?? 50;

    final wordsToday = ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
    final canStartNewList = wordsToday < dailyWordListLimit;

    final children = <Widget>[];
    bool foundActive = false;

    for (int unitIdx = 0; unitIdx < units.length; unitIdx++) {
      final unit = units[unitIdx];
      final isUnitLocked = unitIdx > 0 && !units[unitIdx - 1].isAllComplete;

      // Unit divider
      children.add(UnitDivider(
        unitIndex: unitIdx,
        unitName: unit.unit.name,
        unitIcon: unit.unit.icon,
        isLocked: isUnitLocked,
      ));

      // Calculate locks for items within this unit
      final locks = calculateLocks(
        items: unit.items,
        sequentialLock: unit.sequentialLock,
        booksExemptFromLock: unit.booksExemptFromLock,
        isUnitLocked: isUnitLocked,
      );

      // Build node data list for this tile
      final tileNodes = <MapTileNodeData>[];

      for (int itemIdx = 0; itemIdx < unit.items.length; itemIdx++) {
        final item = unit.items[itemIdx];
        final isItemLocked = locks[itemIdx];

        // Active detection: first unlocked + incomplete (skip daily review)
        bool isActive = false;
        if (!foundActive && !isItemLocked && !item.isComplete && item is! PathDailyReviewItem) {
          isActive = true;
          foundActive = true;
        }

        final nodeState = isItemLocked
            ? NodeState.locked
            : isActive
                ? NodeState.active
                : item.isComplete
                    ? NodeState.completed
                    : NodeState.available;

        tileNodes.add(_mapItemToNode(
          context: context,
          ref: ref,
          item: item,
          state: nodeState,
          unit: unit,
          star3: star3,
          star2: star2,
          star1: star1,
          canStartNewList: canStartNewList,
        ));
      }

      // Map tile
      final theme = tileThemeForUnit(unitIdx);
      children.add(MapTile(theme: theme, nodes: tileNodes));
    }

    return Column(children: children);
  }

  MapTileNodeData _mapItemToNode({
    required BuildContext context,
    required WidgetRef ref,
    required PathItemData item,
    required NodeState state,
    required PathUnitData unit,
    required int star3,
    required int star2,
    required int star1,
    required bool canStartNewList,
  }) {
    switch (item) {
      case PathWordListItem(:final wordListWithProgress):
        final wl = wordListWithProgress;
        final stars = wl.starCountWith(star3: star3, star2: star2, star1: star1);
        final unitColor = parseUnitColor(unit.unit.color);

        return MapTileNodeData(
          type: NodeType.wordList,
          state: state,
          label: wl.wordList.name,
          starCount: stars,
          onTap: () {
            if (wl.isStarted && wl.progress != null) {
              showNodeProgressSheet(
                context,
                data: NodeProgressData(
                  name: wl.wordList.name,
                  totalSessions: wl.progress!.totalSessions,
                  bestAccuracy: wl.progress!.bestAccuracy,
                  bestScore: wl.progress!.bestScore,
                  starCount: stars,
                  unitColor: unitColor,
                ),
                onPractice: () => context.push(
                  AppRoutes.vocabularySessionPath(wl.wordList.id),
                ),
              );
            } else {
              context.push(AppRoutes.wordListDetailPath(wl.wordList.id));
            }
          },
        );

      case PathBookItem(:final bookWithProgress):
        return MapTileNodeData(
          type: NodeType.book,
          state: state,
          label: bookWithProgress.book.title,
          onTap: () => context.go(AppRoutes.bookDetailPath(bookWithProgress.bookId)),
        );

      case PathGameItem():
        return MapTileNodeData(
          type: NodeType.game,
          state: state,
          label: 'Game',
          onTap: () => completePathNode(ref, unit.unit.id, 'game'),
        );

      case PathTreasureItem():
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          onTap: () => completePathNode(ref, unit.unit.id, 'treasure'),
        );

      case PathDailyReviewItem():
        return MapTileNodeData(
          type: NodeType.review,
          state: state,
          label: 'Review',
          onTap: () => context.push(AppRoutes.dailyReview),
        );
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(Icons.route_rounded, size: 48,
              color: AppColors.neutralText.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No learning path yet',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your teacher will assign one soon!',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.neutralText.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify route helpers exist**

Check that `AppRoutes.vocabularySessionPath`, `AppRoutes.wordListDetailPath`, `AppRoutes.bookDetailPath`, `AppRoutes.dailyReview` exist:

```bash
grep -n "vocabularySessionPath\|wordListDetailPath\|bookDetailPath\|dailyReview" lib/app/router.dart
```

If any are missing, check the exact route helper names in `router.dart` and update the orchestrator accordingly.

- [ ] **Step 3: Check parseUnitColor exists**

```bash
grep -n "parseUnitColor" lib/presentation/utils/ui_helpers.dart
```

If it doesn't exist, check for `VocabularyUnitColor` extension or similar helper and update usage.

- [ ] **Step 4: Verify**

```bash
dart analyze lib/presentation/widgets/learning_path/learning_path.dart
```

Fix any import or naming issues. Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/learning_path/learning_path.dart
git commit -m "feat: add LearningPathView orchestrator with tile-based rendering"
```

---

### Task 9: Wire up to vocabulary_hub_screen.dart

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`

- [ ] **Step 1: Update imports and swap LearningPath widget**

Replace the legacy import:
```dart
// Old:
import '../../widgets/vocabulary/learning_path_legacy.dart';
// New:
import '../../widgets/learning_path/learning_path.dart';
```

In the build method, replace `LearningPath()` with `LearningPathView()`:
```dart
// Old:
const LearningPath(),
// New:
const LearningPathView(),
```

- [ ] **Step 2: Remove terrain background (if switching to tile-based)**

The `TerrainBackground` widget wraps the entire screen. Since tiles now provide their own backgrounds, replace:

```dart
// Old:
body: TerrainBackground(
  child: SafeArea(
// New:
body: SafeArea(
```

Update `backgroundColor` from `AppColors.terrain` to `AppColors.background`:

```dart
backgroundColor: AppColors.background,
```

Remove the unused import:
```dart
// Remove:
import '../../widgets/common/terrain_background.dart';
```

- [ ] **Step 3: Verify build**

```bash
dart analyze lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
```

Expected: No errors.

- [ ] **Step 4: Test in browser**

```bash
flutter run -d chrome
```

Navigate to Learning Path tab. Expected:
- Placeholder gradient tiles with dot pattern
- Nodes positioned on each tile
- Active node has START bubble
- Tapping word list nodes opens progress sheet
- Unit dividers between tiles

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
git commit -m "feat: wire new tile-based learning path to vocabulary hub screen"
```

---

### Task 10: Verify and fix auto-scroll

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`

- [ ] **Step 1: Update activeNodeYProvider calculation**

The existing `activeNodeYProvider` may reference old positioning logic. Update the scroll target calculation in `vocabulary_hub_screen.dart` to use tile-based coordinates:

In the `ref.listen<double?>(activeNodeYProvider, ...)` callback, the Y offset is now deterministic:
- Each unit = `kDividerHeight + kTileHeight` = `60 + 1000 = 1060px`
- Node Y within tile = `nodePosition.dy * kTileHeight`

If `activeNodeYProvider` still works correctly (it computes from the learning path data), keep it. If it references old Y accumulation logic, update it to:

```dart
// In vocabulary_provider.dart — activeNodeYProvider
// Compute based on: unitIndex * (kTileHeight + kDividerHeight) + slotIndex * (kTileHeight / slotCount)
```

Check if scrolling works correctly by testing in browser. If the auto-scroll target is wrong, update the provider.

- [ ] **Step 2: Test auto-scroll**

Navigate away from Learning Path and back. Verify it scrolls to the active node.

- [ ] **Step 3: Commit (if changes needed)**

```bash
git add -A
git commit -m "fix: update auto-scroll calculation for tile-based learning path"
```

---

### Task 11: Clean up and final verification

**Files:**
- All new files in `lib/presentation/widgets/learning_path/`
- `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`

- [ ] **Step 1: Full analysis**

```bash
dart analyze lib/
```

Fix any warnings or errors.

- [ ] **Step 2: Test all node types**

In the browser, verify:
- [ ] Word list nodes: tap opens progress sheet, stars display
- [ ] Book nodes: tap navigates to book detail
- [ ] Game nodes: tap completes game
- [ ] Treasure nodes: tap claims treasure
- [ ] Review nodes: tap navigates to daily review
- [ ] Locked nodes: gray, not tappable
- [ ] Active node: bounce animation + START bubble
- [ ] Completed nodes: green check overlay

- [ ] **Step 3: Test responsive behavior**

- [ ] Mobile width (<600px): edges cropped, path centered
- [ ] Tablet (600-800px): slight cropping
- [ ] Desktop (>800px): full tile visible
- [ ] Right panel visible at ≥1000px

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: complete learning path redesign with tile-based map system"
```
