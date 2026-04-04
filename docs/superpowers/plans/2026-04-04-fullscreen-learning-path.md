# Fullscreen Immersive Learning Path — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fullscreen immersive mode to the learning path so students can explore the map without sidebar, right panel, or navigation bars — with landscape support on mobile.

**Architecture:** Two new screens (`FullscreenMapScreen`, `FullscreenUnitDetailScreen`) registered as root-navigator routes bypass the shell entirely. They reuse the existing `MapTile`, `PathNode`, and provider logic from `UnitMapScreen`/`UnitDetailScreen`. An expand button on the existing `UnitMapScreen` is the entry point.

**Tech Stack:** Flutter, GoRouter, Riverpod, SystemChrome (orientation)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/app/router.dart` | Modify | Add route helpers + 2 root-navigator routes + imports |
| `lib/presentation/screens/vocabulary/unit_map_screen.dart` | Modify | Add expand button overlay (top-right) |
| `lib/presentation/screens/vocabulary/fullscreen_map_screen.dart` | Create | Fullscreen unit-level map with minimize button + orientation |
| `lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart` | Create | Fullscreen unit-detail map with back + minimize buttons + orientation |

---

### Task 1: Add Route Helpers to AppRoutes

**Files:**
- Modify: `lib/app/router.dart:109-112` (after existing `vocabularyPathUnit` helper)

- [ ] **Step 1: Add the two fullscreen route helper methods**

In `lib/app/router.dart`, after line 112 (`vocabularyPathUnit` helper), add:

```dart
  static String vocabularyPathFullscreen(String pathId) =>
      '/vocabulary/path/$pathId/fullscreen';
  static String vocabularyPathFullscreenUnit(String pathId, int unitIdx) =>
      '/vocabulary/path/$pathId/fullscreen/unit/$unitIdx';
```

- [ ] **Step 2: Run analyze to verify**

Run: `dart analyze lib/app/router.dart`
Expected: No errors (warnings about unused are fine — routes not wired yet)

- [ ] **Step 3: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat: add fullscreen learning path route helpers"
```

---

### Task 2: Create FullscreenMapScreen

**Files:**
- Create: `lib/presentation/screens/vocabulary/fullscreen_map_screen.dart`

This screen replicates `UnitMapScreen`'s build logic but without the shell — no `TopNavbar`, full `Scaffold` with `SafeArea`, minimize button overlay, and landscape orientation support.

- [ ] **Step 1: Create the fullscreen map screen file**

Create `lib/presentation/screens/vocabulary/fullscreen_map_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../providers/tile_theme_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/learning_path/map_tile.dart';
import '../../widgets/learning_path/path_node.dart';
import '../../widgets/learning_path/tile_themes.dart';

/// Fullscreen immersive unit map — no shell, no sidebar, no right panel.
/// Entry point: expand button on UnitMapScreen.
class FullscreenMapScreen extends ConsumerStatefulWidget {
  const FullscreenMapScreen({super.key, required this.pathId});
  final String pathId;

  @override
  ConsumerState<FullscreenMapScreen> createState() =>
      _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends ConsumerState<FullscreenMapScreen> {
  final _scrollController = ScrollController();
  bool _hasScrolled = false;
  final _precachedUrls = <String>{};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _scrollController.dispose();
    super.dispose();
  }

  void _precacheTileImages(BuildContext context, List<TileThemeEntity> themes) {
    for (final theme in themes) {
      final url = theme.imageUrl;
      if (url != null && _precachedUrls.add(url)) {
        precacheImage(NetworkImage(url), context);
      }
    }
  }

  void _minimize() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final pathDataAsync = ref.watch(learningPathProvider);
    final paths = ref.watch(userLearningPathsProvider).valueOrNull ?? [];
    final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: pathDataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Could not load learning path',
              style: GoogleFonts.nunito(color: AppColors.neutralText),
            ),
          ),
          data: (allUnits) {
            if (dbThemes.isNotEmpty) {
              _precacheTileImages(context, dbThemes);
            }

            final path =
                paths.where((p) => p.id == widget.pathId).firstOrNull;
            if (path == null) {
              return Center(
                child: Text(
                  'Learning path not found',
                  style: GoogleFonts.nunito(color: AppColors.neutralText),
                ),
              );
            }

            final units = allUnits
                .where((pu) => pu.pathId == widget.pathId)
                .toList();

            final theme = _resolvePathTheme(path.tileThemeId, dbThemes);

            // Find active unit index
            int? activeIdx;
            for (int i = 0; i < units.length; i++) {
              final isLocked =
                  path.unitGate && i > 0 && !units[i - 1].isAllComplete;
              if (!isLocked && !units[i].isAllComplete) {
                activeIdx = i;
                break;
              }
            }

            // Auto-scroll to active unit
            if (activeIdx != null && !_hasScrolled && theme != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_hasScrolled && _scrollController.hasClients) {
                  _hasScrolled = true;
                  final nodeY = activeIdx! < theme.nodePositions.length
                      ? theme.nodePositions[activeIdx].dy * theme.height
                      : 0.0;
                  final screenH = MediaQuery.of(context).size.height;
                  final target = (nodeY - screenH / 2).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  );
                  _scrollController.jumpTo(target);
                }
              });
            }

            return Stack(
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: theme != null
                        ? _buildTileMap(
                            context, units, theme, activeIdx, path.unitGate)
                        : _buildSimpleUnitList(
                            context, units, activeIdx, path.unitGate),
                  ),
                ),
                // Minimize button — top-right
                Positioned(
                  top: 12,
                  right: 12,
                  child: _CircleButton(
                    icon: Icons.close_fullscreen_rounded,
                    onTap: _minimize,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTileMap(
    BuildContext context,
    List<PathUnitData> units,
    TileTheme theme,
    int? activeIdx,
    bool unitGate,
  ) {
    final nodeData = <MapTileNodeData>[];
    for (int i = 0; i < units.length; i++) {
      final unit = units[i];
      final isLocked = unitGate && i > 0 && !units[i - 1].isAllComplete;
      final isActive = i == activeIdx;
      final isComplete = unit.isAllComplete;

      final state = isLocked
          ? NodeState.locked
          : isActive
              ? NodeState.active
              : isComplete
                  ? NodeState.completed
                  : NodeState.available;

      nodeData.add(
        MapTileNodeData(
          type: NodeType.wordList,
          state: state,
          unitNumber: i + 1,
          onTap: isLocked
              ? null
              : () => context.push(
                    AppRoutes.vocabularyPathFullscreenUnit(
                        widget.pathId, i),
                  ),
        ),
      );
    }

    return MapTile(theme: theme, nodes: nodeData);
  }

  Widget _buildSimpleUnitList(
    BuildContext context,
    List<PathUnitData> units,
    int? activeIdx,
    bool unitGate,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < units.length; i++)
            _UnitCard(
              unit: units[i],
              index: i,
              isLocked: unitGate && i > 0 && !units[i - 1].isAllComplete,
              isActive: i == activeIdx,
              onTap: () => context.push(
                AppRoutes.vocabularyPathFullscreenUnit(widget.pathId, i),
              ),
            ),
        ],
      ),
    );
  }

  TileTheme? _resolvePathTheme(
      String? themeId, List<TileThemeEntity> dbThemes) {
    if (themeId == null || dbThemes.isEmpty) return null;
    final match = dbThemes.where((t) => t.id == themeId).firstOrNull;
    if (match == null) return null;
    return TileTheme(
      name: match.name,
      assetPath: '',
      height: match.height.toDouble(),
      nodePositions:
          match.nodePositions.map((p) => Offset(p.x, p.y)).toList(),
      fallbackColors: [
        _parseHex(match.fallbackColor1),
        _parseHex(match.fallbackColor2),
      ],
      imageUrl: match.imageUrl,
    );
  }

  static Color _parseHex(String hex) {
    if (hex.length < 7) return const Color(0xFF58CC02);
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF58CC02);
    }
  }
}

/// Simple unit card fallback (same as UnitMapScreen._UnitCard).
class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.index,
    required this.isLocked,
    required this.isActive,
    required this.onTap,
  });

  final PathUnitData unit;
  final int index;
  final bool isLocked;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isLocked
        ? AppColors.neutral
        : isActive
            ? AppColors.secondary
            : unit.isAllComplete
                ? AppColors.primary
                : AppColors.neutralText;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.15),
              child: isLocked
                  ? Icon(Icons.lock_rounded, color: color, size: 20)
                  : Text(unit.unit.icon ?? '📚',
                      style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit ${index + 1}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    unit.unit.name,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color:
                          isLocked ? AppColors.neutralText : AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
            if (unit.isAllComplete)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 28),
            if (isActive)
              const Icon(Icons.play_circle_rounded,
                  color: AppColors.secondary, size: 28),
          ],
        ),
      ),
    );
  }
}

/// Reusable circular overlay button (minimize / back).
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: AppColors.black),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/presentation/screens/vocabulary/fullscreen_map_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/fullscreen_map_screen.dart
git commit -m "feat: create FullscreenMapScreen for immersive learning path"
```

---

### Task 3: Create FullscreenUnitDetailScreen

**Files:**
- Create: `lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart`

This screen replicates `UnitDetailScreen`'s build logic but without the shell — no `TopNavbar`, full `Scaffold` with `SafeArea`, back button (top-left), minimize button (top-right), and landscape orientation support. Minimize uses `context.go()` to clear the fullscreen push stack.

- [ ] **Step 1: Create the fullscreen unit detail screen file**

Create `lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/tile_theme_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/learning_path/map_tile.dart';
import '../../widgets/learning_path/path_node.dart';
import '../../widgets/learning_path/tile_themes.dart';

/// Fullscreen immersive unit detail — shows a single unit's items
/// (word lists, books, game, treasure) on a tile map without shell chrome.
class FullscreenUnitDetailScreen extends ConsumerStatefulWidget {
  const FullscreenUnitDetailScreen({
    super.key,
    required this.pathId,
    required this.unitIdx,
  });

  final String pathId;
  final int unitIdx;

  @override
  ConsumerState<FullscreenUnitDetailScreen> createState() =>
      _FullscreenUnitDetailScreenState();
}

class _FullscreenUnitDetailScreenState
    extends ConsumerState<FullscreenUnitDetailScreen> {
  final _scrollController = ScrollController();
  bool _hasScrolled = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _scrollController.dispose();
    super.dispose();
  }

  void _minimize() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    context.go(AppRoutes.vocabularyPathUnits(widget.pathId));
  }

  @override
  Widget build(BuildContext context) {
    final pathDataAsync = ref.watch(learningPathProvider);
    final paths = ref.watch(userLearningPathsProvider).valueOrNull ?? [];
    final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: pathDataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Could not load unit',
              style: GoogleFonts.nunito(color: AppColors.neutralText),
            ),
          ),
          data: (allUnits) {
            final path =
                paths.where((p) => p.id == widget.pathId).firstOrNull;
            if (path == null || widget.unitIdx >= path.units.length) {
              return const Center(child: Text('Unit not found'));
            }

            final pathUnits = allUnits
                .where((pu) => pu.pathId == widget.pathId)
                .toList();
            final unitData = widget.unitIdx < pathUnits.length
                ? pathUnits[widget.unitIdx]
                : null;
            if (unitData == null) {
              return const Center(child: Text('Unit data not found'));
            }

            // Find active node index for auto-scroll
            final locks = calculateLocks(
              items: unitData.items,
              sequentialLock: unitData.sequentialLock,
              booksExemptFromLock: unitData.booksExemptFromLock,
              isUnitLocked: false,
            );
            int? activeIdx;
            for (int i = 0; i < unitData.items.length; i++) {
              if (!locks[i] && !unitData.items[i].isComplete) {
                activeIdx = i;
                break;
              }
            }

            // Auto-scroll to active node
            if (activeIdx != null && !_hasScrolled) {
              final theme = _resolveTheme(
                  unitData.tileThemeId, widget.unitIdx, dbThemes);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_hasScrolled && _scrollController.hasClients) {
                  _hasScrolled = true;
                  if (activeIdx! < theme.nodePositions.length) {
                    final nodeY =
                        theme.nodePositions[activeIdx].dy * theme.height;
                    final screenW = MediaQuery.sizeOf(context).width;
                    final scale = screenW / kTileWidth;
                    final scrollTarget = (nodeY * scale -
                            MediaQuery.sizeOf(context).height / 3)
                        .clamp(
                      0.0,
                      _scrollController.position.maxScrollExtent,
                    );
                    _scrollController.animateTo(
                      scrollTarget,
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                    );
                  }
                }
              });
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildUnitTile(context, ref, unitData, dbThemes),
                ),
                // Back button — top-left
                Positioned(
                  top: 12,
                  left: 12,
                  child: _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                ),
                // Minimize button — top-right
                Positioned(
                  top: 12,
                  right: 12,
                  child: _CircleButton(
                    icon: Icons.close_fullscreen_rounded,
                    onTap: _minimize,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnitTile(
    BuildContext context,
    WidgetRef ref,
    PathUnitData unitData,
    List<TileThemeEntity> dbThemes,
  ) {
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    final star3 = settings?.starRating3 ?? 90;
    final star2 = settings?.starRating2 ?? 70;
    final star1 = settings?.starRating1 ?? 50;

    final theme =
        _resolveTheme(unitData.tileThemeId, widget.unitIdx, dbThemes);

    // Build assignment lookup
    final activeAssignments =
        ref.watch(activeAssignmentsProvider).valueOrNull ?? [];
    final assignedWordListIds = <String>{};
    final assignedBookIds = <String>{};
    final assignedUnitIds = <String>{};
    for (final a in activeAssignments) {
      if (a.wordListId != null) assignedWordListIds.add(a.wordListId!);
      if (a.bookId != null) assignedBookIds.add(a.bookId!);
      if (a.unitId != null) assignedUnitIds.add(a.unitId!);
    }

    final locks = calculateLocks(
      items: unitData.items,
      sequentialLock: unitData.sequentialLock,
      booksExemptFromLock: unitData.booksExemptFromLock,
      isUnitLocked: false,
    );

    bool foundActive = false;
    final tileNodes = <MapTileNodeData>[];

    for (int i = 0; i < unitData.items.length; i++) {
      final item = unitData.items[i];
      final isItemLocked = locks[i];

      bool isActive = false;
      if (!foundActive && !isItemLocked && !item.isComplete) {
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

      tileNodes.add(
        _mapItemToNode(
          context: context,
          ref: ref,
          item: item,
          state: nodeState,
          unitData: unitData,
          star3: star3,
          star2: star2,
          star1: star1,
          isFirstItem: i == 0,
          assignedWordListIds: assignedWordListIds,
          assignedBookIds: assignedBookIds,
          assignedUnitIds: assignedUnitIds,
        ),
      );
    }

    return MapTile(theme: theme, nodes: tileNodes);
  }

  MapTileNodeData _mapItemToNode({
    required BuildContext context,
    required WidgetRef ref,
    required PathItemData item,
    required NodeState state,
    required PathUnitData unitData,
    required int star3,
    required int star2,
    required int star1,
    required bool isFirstItem,
    required Set<String> assignedWordListIds,
    required Set<String> assignedBookIds,
    required Set<String> assignedUnitIds,
  }) {
    final unitAssigned = assignedUnitIds.contains(unitData.unit.id);

    switch (item) {
      case PathWordListItem(:final wordListWithProgress):
        final wl = wordListWithProgress;
        final stars =
            wl.starCountWith(star3: star3, star2: star2, star1: star1);
        return MapTileNodeData(
          type: NodeType.wordList,
          state: state,
          label: wl.wordList.name,
          starCount: stars,
          totalSessions: wl.progress?.totalSessions,
          bestAccuracy: wl.progress?.bestAccuracy,
          bestScore: wl.progress?.bestScore,
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned ||
              assignedWordListIds.contains(wl.wordList.id),
          onTap: () => context
              .push(AppRoutes.vocabularySessionPath(wl.wordList.id)),
        );

      case PathBookItem(:final bookWithProgress):
        return MapTileNodeData(
          type: NodeType.book,
          state: state,
          label: bookWithProgress.book.title,
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned ||
              assignedBookIds.contains(bookWithProgress.bookId),
          onTap: () => context.push(
              AppRoutes.bookDetailPath(bookWithProgress.bookId)),
        );

      case PathGameItem():
        return MapTileNodeData(
          type: NodeType.game,
          state: state,
          label: 'Game',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: () => completePathNode(ref, unitData.unit.id, 'game'),
        );

      case PathTreasureItem():
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: () =>
              completePathNode(ref, unitData.unit.id, 'treasure'),
        );
    }
  }

  TileTheme _resolveTheme(
      String? themeId, int fallbackIdx, List<TileThemeEntity> dbThemes) {
    if (themeId != null && dbThemes.isNotEmpty) {
      final match = dbThemes.where((t) => t.id == themeId).firstOrNull;
      if (match != null) {
        return TileTheme(
          name: match.name,
          assetPath: '',
          height: match.height.toDouble(),
          nodePositions:
              match.nodePositions.map((p) => Offset(p.x, p.y)).toList(),
          fallbackColors: [
            _parseHex(match.fallbackColor1),
            _parseHex(match.fallbackColor2),
          ],
          imageUrl: match.imageUrl,
        );
      }
    }
    return tileThemeForUnit(fallbackIdx);
  }

  static Color _parseHex(String hex) {
    if (hex.length < 7) return const Color(0xFF58CC02);
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF58CC02);
    }
  }
}

/// Reusable circular overlay button (minimize / back).
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: AppColors.black),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart
git commit -m "feat: create FullscreenUnitDetailScreen for immersive unit detail"
```

---

### Task 4: Register Fullscreen Routes in Router

**Files:**
- Modify: `lib/app/router.dart:1-49` (imports) and `lib/app/router.dart:520-538` (route registration, after pack opening)

- [ ] **Step 1: Add imports for the two new screens**

In `lib/app/router.dart`, after line 23 (`import ...unit_detail_screen.dart`), add:

```dart
import '../presentation/screens/vocabulary/fullscreen_map_screen.dart';
import '../presentation/screens/vocabulary/fullscreen_unit_detail_screen.dart';
```

- [ ] **Step 2: Add the two GoRoute entries**

In `lib/app/router.dart`, after the pack opening route (after line 525 `),`), add:

```dart
      // Fullscreen immersive learning path (no shell)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/vocabulary/path/:pathId/fullscreen',
        builder: (context, state) {
          final pathId = state.pathParameters['pathId']!;
          return FullscreenMapScreen(pathId: pathId);
        },
        routes: [
          GoRoute(
            parentNavigatorKey: rootNavigatorKey,
            path: 'unit/:unitIdx',
            builder: (context, state) {
              final pathId = state.pathParameters['pathId']!;
              final unitIdx =
                  int.parse(state.pathParameters['unitIdx']!);
              return FullscreenUnitDetailScreen(
                  pathId: pathId, unitIdx: unitIdx);
            },
          ),
        ],
      ),
```

- [ ] **Step 3: Run analyze**

Run: `dart analyze lib/app/router.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat: register fullscreen learning path routes in router"
```

---

### Task 5: Add Expand Button to UnitMapScreen

**Files:**
- Modify: `lib/presentation/screens/vocabulary/unit_map_screen.dart:112-123`

The expand button goes in the existing `Stack` that wraps the scroll content. Currently `UnitMapScreen` does NOT have a Stack — the content is just a `SingleChildScrollView`. We need to wrap it in a Stack and add the button.

- [ ] **Step 1: Add the import for services (not needed — no orientation here) and wrap content in Stack**

In `lib/presentation/screens/vocabulary/unit_map_screen.dart`, replace the return block (lines 112-121) from:

```dart
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: theme != null
                    ? _buildTileMap(context, units, theme, activeIdx, path.unitGate)
                    : _buildSimpleUnitList(context, units, activeIdx, path.unitGate),
              ),
            );
```

to:

```dart
            return Stack(
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: theme != null
                        ? _buildTileMap(context, units, theme, activeIdx, path.unitGate)
                        : _buildSimpleUnitList(context, units, activeIdx, path.unitGate),
                  ),
                ),
                // Expand to fullscreen button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.vocabularyPathFullscreen(widget.pathId),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        size: 22,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ),
              ],
            );
```

- [ ] **Step 2: Run analyze**

Run: `dart analyze lib/presentation/screens/vocabulary/unit_map_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/unit_map_screen.dart
git commit -m "feat: add expand-to-fullscreen button on UnitMapScreen"
```

---

### Task 6: Smoke Test & Final Verify

- [ ] **Step 1: Run full analyze**

Run: `dart analyze lib/`
Expected: No new errors (existing warnings are fine)

- [ ] **Step 2: Manual smoke test checklist**

Run the app (`flutter run -d chrome`) and verify:

1. Navigate to Learning Path → Unit Map
2. Verify expand button visible at top-right
3. Tap expand → fullscreen map loads (no sidebar, no right panel, no navbar)
4. Tap a unit → fullscreen unit detail loads
5. Tap a word list node → popup appears → START → vocab session opens
6. Back from session → returns to fullscreen unit detail
7. Tap back button (top-left) → returns to fullscreen map
8. Tap minimize (top-right) → returns to normal UnitMapScreen in shell
9. Re-enter fullscreen → go to unit detail → tap minimize → returns to normal UnitMapScreen (context.go clears stack)
10. Android back / ESC works correctly at each level

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: fullscreen learning path smoke test fixes"
```
