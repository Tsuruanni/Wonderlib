# Unit Map Navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the vocabulary hub into a 3-layer navigation: path selection → unit map (tile-based) → unit detail (existing tile). Each learning path gets its own tile theme for the unit map background.

**Architecture:** New `tile_theme_id` on `scope_learning_paths` / `learning_path_templates`. Rewritten `VocabularyHubScreen` that conditionally shows path selection or unit map. New `UnitMapView` widget (tile-based, reuses `MapTile` pattern). New `UnitDetailScreen` that renders a single unit's items. Existing `LearningPathView` becomes the single-unit renderer.

**Tech Stack:** Flutter, Riverpod, go_router, Supabase (PostgreSQL RPC), existing tile theme system

**Spec:** `docs/superpowers/specs/2026-03-30-unit-map-navigation-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `supabase/migrations/2026MMDD_path_tile_theme.sql` | Create | Add `tile_theme_id` to `scope_learning_paths` + `learning_path_templates`, update RPC |
| `lib/domain/entities/learning_path.dart` | Modify | Add `tileThemeId` to `LearningPath` |
| `lib/data/models/vocabulary/learning_path_model.dart` | Modify | Parse `lp_tile_theme_id` from RPC |
| `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart` | Rewrite | Path selection (2+ paths) or direct unit map (1 path) |
| `lib/presentation/widgets/learning_path/unit_map_view.dart` | Create | Tile-based unit node map for a single learning path |
| `lib/presentation/screens/vocabulary/unit_detail_screen.dart` | Create | Single unit's items rendered via existing tile |
| `lib/presentation/widgets/learning_path/learning_path.dart` | Modify | Render single unit only (receives filtered data) |
| `lib/presentation/providers/vocabulary_provider.dart` | Modify | Add path-level providers, simplify activeNodeY |
| `lib/app/router.dart` | Modify | Add new routes |
| `owlio_admin/lib/features/templates/screens/template_edit_screen.dart` | Modify | Path-level tile theme dropdown |
| `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart` | Modify | Path-level tile theme dropdown |

---

### Task 1: Database migration — path-level tile_theme_id + RPC update

**Files:**
- Create: `supabase/migrations/20260330300001_path_tile_theme.sql`

- [ ] **Step 1: Write migration**

```sql
-- Add tile_theme_id to learning path tables (path-level theme for unit map)
ALTER TABLE scope_learning_paths
  ADD COLUMN tile_theme_id UUID REFERENCES tile_themes(id) ON DELETE SET NULL;

ALTER TABLE learning_path_templates
  ADD COLUMN tile_theme_id UUID REFERENCES tile_themes(id) ON DELETE SET NULL;

-- Update RPC to return path-level tile_theme_id
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID);

CREATE OR REPLACE FUNCTION get_user_learning_paths(p_user_id UUID)
RETURNS TABLE (
  learning_path_id        UUID,
  learning_path_name      VARCHAR,
  lp_sort_order           INTEGER,
  sequential_lock         BOOLEAN,
  books_exempt_from_lock  BOOLEAN,
  unit_gate               BOOLEAN,
  lp_tile_theme_id        UUID,
  unit_id                 UUID,
  unit_name               VARCHAR,
  unit_color              VARCHAR,
  unit_icon               VARCHAR,
  unit_sort_order         INTEGER,
  tile_theme_id           UUID,
  item_type               VARCHAR,
  item_id                 UUID,
  item_sort_order         INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_grade INTEGER;
  v_class_id UUID;
BEGIN
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT p.school_id, c.grade, p.class_id
  INTO v_school_id, v_grade, v_class_id
  FROM profiles p
  LEFT JOIN classes c ON c.id = p.class_id
  WHERE p.id = p_user_id;

  IF v_school_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    slp.id AS learning_path_id,
    slp.name::VARCHAR AS learning_path_name,
    slp.sort_order AS lp_sort_order,
    slp.sequential_lock,
    slp.books_exempt_from_lock,
    slp.unit_gate,
    slp.tile_theme_id AS lp_tile_theme_id,
    vu.id AS unit_id,
    vu.name::VARCHAR AS unit_name,
    vu.color::VARCHAR AS unit_color,
    vu.icon::VARCHAR AS unit_icon,
    slpu.sort_order AS unit_sort_order,
    slpu.tile_theme_id,
    sui.item_type::VARCHAR AS item_type,
    COALESCE(sui.word_list_id, sui.book_id) AS item_id,
    sui.sort_order AS item_sort_order
  FROM scope_learning_paths slp
  JOIN scope_learning_path_units slpu ON slpu.scope_learning_path_id = slp.id
  JOIN vocabulary_units vu ON vu.id = slpu.unit_id
  LEFT JOIN scope_unit_items sui ON sui.scope_lp_unit_id = slpu.id
  WHERE slp.school_id = v_school_id
    AND (
      (slp.grade IS NULL AND slp.class_id IS NULL)
      OR (slp.grade = v_grade AND slp.class_id IS NULL)
      OR (slp.class_id = v_class_id)
    )
    AND vu.is_active = true
  ORDER BY slp.sort_order, slpu.sort_order, sui.sort_order;
END;
$$;

-- Update apply_learning_path_template to copy tile_theme_id
DROP FUNCTION IF EXISTS apply_learning_path_template(UUID, UUID, INTEGER, UUID);

CREATE OR REPLACE FUNCTION apply_learning_path_template(
  p_template_id UUID,
  p_school_id UUID,
  p_grade INTEGER DEFAULT NULL,
  p_class_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template RECORD;
  v_scope_path_id UUID;
  v_template_unit RECORD;
  v_scope_unit_id UUID;
  v_template_item RECORD;
BEGIN
  SELECT name, sequential_lock, books_exempt_from_lock, unit_gate, tile_theme_id
  INTO v_template
  FROM learning_path_templates
  WHERE id = p_template_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template not found: %', p_template_id;
  END IF;

  v_scope_path_id := gen_random_uuid();

  INSERT INTO scope_learning_paths (
    id, school_id, grade, class_id, name, template_id,
    sequential_lock, books_exempt_from_lock, unit_gate, tile_theme_id
  ) VALUES (
    v_scope_path_id, p_school_id, p_grade, p_class_id,
    v_template.name, p_template_id,
    v_template.sequential_lock, v_template.books_exempt_from_lock,
    v_template.unit_gate, v_template.tile_theme_id
  );

  FOR v_template_unit IN
    SELECT id, unit_id, sort_order, tile_theme_id
    FROM learning_path_template_units
    WHERE template_id = p_template_id
    ORDER BY sort_order
  LOOP
    v_scope_unit_id := gen_random_uuid();

    INSERT INTO scope_learning_path_units (
      id, scope_learning_path_id, unit_id, sort_order, tile_theme_id
    ) VALUES (
      v_scope_unit_id, v_scope_path_id,
      v_template_unit.unit_id, v_template_unit.sort_order,
      v_template_unit.tile_theme_id
    );

    FOR v_template_item IN
      SELECT item_type, word_list_id, book_id, sort_order
      FROM learning_path_template_items
      WHERE template_unit_id = v_template_unit.id
      ORDER BY sort_order
    LOOP
      INSERT INTO scope_unit_items (
        id, scope_lp_unit_id, item_type, word_list_id, book_id, sort_order
      ) VALUES (
        gen_random_uuid(), v_scope_unit_id,
        v_template_item.item_type, v_template_item.word_list_id,
        v_template_item.book_id, v_template_item.sort_order
      );
    END LOOP;
  END LOOP;

  RETURN v_scope_path_id;
END;
$$;
```

- [ ] **Step 2: Dry-run**

```bash
supabase db push --include-all --dry-run
```

- [ ] **Step 3: Push**

```bash
supabase db push --include-all
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260330300001_path_tile_theme.sql
git commit -m "feat: add path-level tile_theme_id and update RPCs"
```

---

### Task 2: LearningPath entity + model — add tileThemeId

**Files:**
- Modify: `lib/domain/entities/learning_path.dart`
- Modify: `lib/data/models/vocabulary/learning_path_model.dart`

- [ ] **Step 1: Add tileThemeId to LearningPath entity**

In `lib/domain/entities/learning_path.dart`, add to `LearningPath`:

Constructor: add `this.tileThemeId,` after `this.unitGate = true,`
Field: add `final String? tileThemeId;`
Props: add `tileThemeId`

- [ ] **Step 2: Parse lp_tile_theme_id in model**

In `lib/data/models/vocabulary/learning_path_model.dart`:

In `_PathBuilder`:
- Constructor: add `this.tileThemeId,`
- Field: add `final String? tileThemeId;`

In the `putIfAbsent` for `pathBuilder`:
- Add: `tileThemeId: row['lp_tile_theme_id'] as String?,`

In the `LearningPath(...)` construction:
- Add: `tileThemeId: pb.tileThemeId,`

- [ ] **Step 3: Verify**

```bash
dart analyze lib/domain/entities/learning_path.dart lib/data/models/vocabulary/learning_path_model.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/domain/entities/learning_path.dart lib/data/models/vocabulary/learning_path_model.dart
git commit -m "feat: add tileThemeId to LearningPath entity and model"
```

---

### Task 3: New routes

**Files:**
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Add route helpers to AppRoutes**

```dart
// Add to AppRoutes class:
static String vocabularyPathUnits(String pathId) =>
    '/vocabulary/path/$pathId';
static String vocabularyPathUnit(String pathId, int unitIdx) =>
    '/vocabulary/path/$pathId/unit/$unitIdx';
```

- [ ] **Step 2: Add route registrations**

Inside the vocabulary branch routes (after the `daily-review` route, before the closing `]`), add:

```dart
GoRoute(
  path: 'path/:pathId',
  builder: (context, state) {
    final pathId = state.pathParameters['pathId']!;
    return UnitMapScreen(pathId: pathId);
  },
  routes: [
    GoRoute(
      path: 'unit/:unitIdx',
      builder: (context, state) {
        final pathId = state.pathParameters['pathId']!;
        final unitIdx = int.parse(state.pathParameters['unitIdx']!);
        return UnitDetailScreen(pathId: pathId, unitIdx: unitIdx);
      },
    ),
  ],
),
```

Add imports for the new screens (will be created in later tasks — add imports now, create files later):

```dart
import '../presentation/screens/vocabulary/unit_map_screen.dart';
import '../presentation/screens/vocabulary/unit_detail_screen.dart';
```

- [ ] **Step 3: Commit** (will have analyze errors until screens are created — that's OK)

```bash
git add lib/app/router.dart
git commit -m "feat: add vocabulary path and unit routes"
```

---

### Task 4: UnitMapScreen — tile-based unit node map

**Files:**
- Create: `lib/presentation/screens/vocabulary/unit_map_screen.dart`

- [ ] **Step 1: Write UnitMapScreen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../providers/tile_theme_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/top_navbar.dart';
import '../../widgets/learning_path/map_tile.dart';
import '../../widgets/learning_path/path_node.dart';
import '../../widgets/learning_path/start_bubble.dart';
import '../../widgets/learning_path/tile_themes.dart';

/// Displays units of a single learning path as nodes on a tile-based map.
class UnitMapScreen extends ConsumerStatefulWidget {
  const UnitMapScreen({super.key, required this.pathId});
  final String pathId;

  @override
  ConsumerState<UnitMapScreen> createState() => _UnitMapScreenState();
}

class _UnitMapScreenState extends ConsumerState<UnitMapScreen> {
  final _scrollController = ScrollController();
  bool _hasScrolled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pathDataAsync = ref.watch(learningPathProvider);
    final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TopNavbar(),
            Expanded(
              child: pathDataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Could not load learning path',
                      style: GoogleFonts.nunito(color: AppColors.neutralText)),
                ),
                data: (pathUnits) {
                  // Find the specific learning path by ID
                  // pathUnits is grouped by path in learningPathProvider
                  // We need the raw LearningPath list
                  final paths = ref.watch(userLearningPathsProvider).valueOrNull ?? [];
                  final path = paths.where((p) => p.id == widget.pathId).firstOrNull;
                  if (path == null) {
                    return Center(
                      child: Text('Learning path not found',
                          style: GoogleFonts.nunito(color: AppColors.neutralText)),
                    );
                  }

                  // Filter pathUnits for this path's units
                  final unitIds = path.units.map((u) => u.unitId).toSet();
                  final units = pathUnits.where((pu) => unitIds.contains(pu.unit.id)).toList();

                  // Resolve path-level theme
                  final theme = _resolvePathTheme(path.tileThemeId, dbThemes);

                  // Find active unit index (first with incomplete items)
                  int? activeIdx;
                  for (int i = 0; i < units.length; i++) {
                    final isLocked = path.unitGate && i > 0 && !units[i - 1].isAllComplete;
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
                            ? theme.nodePositions[activeIdx].dy * theme.height.toDouble()
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

                  return SingleChildScrollView(
                    controller: _scrollController,
                    child: _buildUnitMap(context, units, theme, activeIdx, path),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitMap(
    BuildContext context,
    List<PathUnitData> units,
    TileTheme? theme,
    int? activeIdx,
    dynamic path,
  ) {
    if (theme == null) {
      // No theme — render simple card list
      return _buildSimpleUnitList(context, units, activeIdx, path);
    }

    // Tile-based map
    final nodeData = <MapTileNodeData>[];
    for (int i = 0; i < units.length; i++) {
      final unit = units[i];
      final isLocked = path.unitGate && i > 0 && !units[i - 1].isAllComplete;
      final isActive = i == activeIdx;
      final isComplete = unit.isAllComplete;

      final state = isLocked
          ? NodeState.locked
          : isActive
              ? NodeState.active
              : isComplete
                  ? NodeState.completed
                  : NodeState.available;

      nodeData.add(MapTileNodeData(
        type: NodeType.wordList,
        state: state,
        label: unit.unit.name,
        onTap: isLocked
            ? null
            : () => context.push(
                  AppRoutes.vocabularyPathUnit(widget.pathId, i),
                ),
      ));
    }

    return MapTile(theme: theme, nodes: nodeData);
  }

  Widget _buildSimpleUnitList(
    BuildContext context,
    List<PathUnitData> units,
    int? activeIdx,
    dynamic path,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < units.length; i++)
            _UnitCard(
              unit: units[i],
              index: i,
              isLocked: path.unitGate && i > 0 && !units[i - 1].isAllComplete,
              isActive: i == activeIdx,
              onTap: () => context.push(
                AppRoutes.vocabularyPathUnit(widget.pathId, i),
              ),
            ),
        ],
      ),
    );
  }

  TileTheme? _resolvePathTheme(String? themeId, List<TileThemeEntity> dbThemes) {
    if (themeId == null || dbThemes.isEmpty) return null;
    final match = dbThemes.where((t) => t.id == themeId).firstOrNull;
    if (match == null) return null;
    return TileTheme(
      name: match.name,
      assetPath: '',
      height: match.height.toDouble(),
      nodePositions: match.nodePositions.map((p) => Offset(p.x, p.y)).toList(),
      fallbackColors: [_parseHex(match.fallbackColor1), _parseHex(match.fallbackColor2)],
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
              : [BoxShadow(color: color.withValues(alpha: 0.3), offset: const Offset(0, 3), blurRadius: 0)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.15),
              child: isLocked
                  ? Icon(Icons.lock_rounded, color: color, size: 20)
                  : Text(unit.unit.icon ?? '📚', style: const TextStyle(fontSize: 20)),
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
                      color: isLocked ? AppColors.neutralText : AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
            if (unit.isAllComplete)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
            if (isActive)
              Icon(Icons.play_circle_rounded, color: AppColors.secondary, size: 28),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze lib/presentation/screens/vocabulary/unit_map_screen.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/unit_map_screen.dart
git commit -m "feat: add UnitMapScreen with tile-based unit map"
```

---

### Task 5: UnitDetailScreen — single unit view

**Files:**
- Create: `lib/presentation/screens/vocabulary/unit_detail_screen.dart`

- [ ] **Step 1: Write UnitDetailScreen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/tile_theme_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/learning_path/map_tile.dart';
import '../../widgets/learning_path/node_progress_sheet.dart';
import '../../widgets/learning_path/path_node.dart';
import '../../widgets/learning_path/tile_themes.dart';

/// Displays a single unit's items (word lists, books, game, treasure, review)
/// on a tile-based map. Essentially the existing LearningPathView for one unit.
class UnitDetailScreen extends ConsumerWidget {
  const UnitDetailScreen({
    super.key,
    required this.pathId,
    required this.unitIdx,
  });

  final String pathId;
  final int unitIdx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathDataAsync = ref.watch(learningPathProvider);
    final paths = ref.watch(userLearningPathsProvider).valueOrNull ?? [];
    final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: pathDataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Could not load unit',
                style: GoogleFonts.nunito(color: AppColors.neutralText)),
          ),
          data: (allUnits) {
            final path = paths.where((p) => p.id == pathId).firstOrNull;
            if (path == null || unitIdx >= path.units.length) {
              return const Center(child: Text('Unit not found'));
            }

            final lpUnit = path.units[unitIdx];
            final unitData = allUnits.where((pu) => pu.unit.id == lpUnit.unitId).firstOrNull;
            if (unitData == null) {
              return const Center(child: Text('Unit data not found'));
            }

            return Column(
              children: [
                // App bar with unit name
                _UnitAppBar(
                  unitName: lpUnit.unitName,
                  unitIcon: lpUnit.unitIcon,
                  unitIdx: unitIdx,
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildUnitTile(context, ref, unitData, dbThemes),
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
    final wordsToday = ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
    final canStartNewList = wordsToday < dailyWordListLimit;

    // Resolve unit-level theme
    final theme = _resolveTheme(unitData.tileThemeId, unitIdx, dbThemes);

    // Build node data
    final locks = calculateLocks(
      items: unitData.items,
      sequentialLock: unitData.sequentialLock,
      booksExemptFromLock: unitData.booksExemptFromLock,
      isUnitLocked: false, // We're already inside the unit
    );

    bool foundActive = false;
    final tileNodes = <MapTileNodeData>[];

    for (int i = 0; i < unitData.items.length; i++) {
      final item = unitData.items[i];
      final isItemLocked = locks[i];

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
        unitData: unitData,
        star3: star3,
        star2: star2,
        star1: star1,
      ));
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
  }) {
    final unitColor = unitData.unit.parsedColor;

    switch (item) {
      case PathWordListItem(:final wordListWithProgress):
        final wl = wordListWithProgress;
        final stars = wl.starCountWith(star3: star3, star2: star2, star1: star1);
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
              context.push(AppRoutes.vocabularyListPath(wl.wordList.id));
            }
          },
        );

      case PathBookItem(:final bookWithProgress):
        return MapTileNodeData(
          type: NodeType.book,
          state: state,
          label: bookWithProgress.book.title,
          onTap: () => context.push(AppRoutes.bookDetailPath(bookWithProgress.bookId)),
        );

      case PathGameItem():
        return MapTileNodeData(
          type: NodeType.game,
          state: state,
          label: 'Game',
          onTap: () => completePathNode(ref, unitData.unit.id, 'game'),
        );

      case PathTreasureItem():
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          onTap: () => completePathNode(ref, unitData.unit.id, 'treasure'),
        );

      case PathDailyReviewItem():
        return MapTileNodeData(
          type: NodeType.review,
          state: state,
          label: 'Review',
          onTap: () => context.push(AppRoutes.vocabularyDailyReview),
        );
    }
  }

  TileTheme _resolveTheme(String? themeId, int fallbackIdx, List<TileThemeEntity> dbThemes) {
    if (themeId != null && dbThemes.isNotEmpty) {
      final match = dbThemes.where((t) => t.id == themeId).firstOrNull;
      if (match != null) {
        return TileTheme(
          name: match.name,
          assetPath: '',
          height: match.height.toDouble(),
          nodePositions: match.nodePositions.map((p) => Offset(p.x, p.y)).toList(),
          fallbackColors: [_parseHex(match.fallbackColor1), _parseHex(match.fallbackColor2)],
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

class _UnitAppBar extends StatelessWidget {
  const _UnitAppBar({
    required this.unitName,
    this.unitIcon,
    required this.unitIdx,
    required this.onBack,
  });

  final String unitName;
  final String? unitIcon;
  final int unitIdx;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
          Text(unitIcon ?? '📚', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit ${unitIdx + 1}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralText,
                  ),
                ),
                Text(
                  unitName,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze lib/presentation/screens/vocabulary/unit_detail_screen.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/unit_detail_screen.dart
git commit -m "feat: add UnitDetailScreen for single unit tile view"
```

---

### Task 6: Rewrite VocabularyHubScreen

**Files:**
- Modify: `lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart`

- [ ] **Step 1: Rewrite the screen**

Replace the entire file content with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/learning_path.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/common/top_navbar.dart';
import 'unit_map_screen.dart';

/// Vocabulary hub — entry point for learning paths.
/// 1 path: shows unit map directly.
/// 2+ paths: shows path selection cards.
class VocabularyHubScreen extends ConsumerWidget {
  const VocabularyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(userLearningPathsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const TopNavbar(),
            Expanded(
              child: pathsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Could not load learning paths',
                    style: GoogleFonts.nunito(color: AppColors.neutralText),
                  ),
                ),
                data: (paths) {
                  if (paths.isEmpty) {
                    return _EmptyState();
                  }
                  if (paths.length == 1) {
                    // Single path — show unit map directly
                    return UnitMapScreen(pathId: paths.first.id);
                  }
                  // Multiple paths — show selection
                  return _PathSelectionList(paths: paths);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathSelectionList extends ConsumerWidget {
  const _PathSelectionList({required this.paths});
  final List<LearningPath> paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUnits = ref.watch(learningPathProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              'Learning Paths',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
          for (final path in paths)
            _PathCard(
              path: path,
              allUnits: allUnits,
              onTap: () => context.push(
                AppRoutes.vocabularyPathUnits(path.id as String),
              ),
            ),
        ],
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.path,
    required this.allUnits,
    required this.onTap,
  });

  final LearningPath path;
  final List<PathUnitData> allUnits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unitIds = (path.units as List).map((u) => u.unitId as String).toSet();
    final pathUnits = allUnits.where((pu) => unitIds.contains(pu.unit.id)).toList();
    final totalUnits = pathUnits.length;
    final completedUnits = pathUnits.where((u) => u.isAllComplete).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.neutral, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.route_rounded, color: AppColors.secondary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path.name as String,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedUnits / $totalUnits units completed',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralText,
                    ),
                  ),
                  if (totalUnits > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalUnits > 0 ? completedUnits / totalUnits : 0,
                        backgroundColor: AppColors.neutral,
                        color: AppColors.primary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: AppColors.neutralText),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
dart analyze lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
```

Fix any issues — `_PathCard` uses `dynamic` for path to avoid import complexity. If `LearningPath` is already imported through providers, use typed access.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/screens/vocabulary/vocabulary_hub_screen.dart
git commit -m "feat: rewrite VocabularyHubScreen with path selection + single path shortcut"
```

---

### Task 7: Admin — path-level tile theme dropdown

**Files:**
- Modify: `owlio_admin/lib/features/templates/screens/template_edit_screen.dart`
- Modify: `owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart`

- [ ] **Step 1: Add path-level theme to template editor**

In template_edit_screen.dart:

Add state field: `String? _pathTileThemeId;`

In `_loadTemplate`, after reading `_unitGate`:
```dart
_pathTileThemeId = template['tile_theme_id'] as String?;
```

In `_handleSave`, add `'tile_theme_id': _pathTileThemeId,` to both INSERT and UPDATE data maps.

In the form, after the "Üniteler arası kilit" SwitchListTile, add:

```dart
const SizedBox(height: 16),
Text('Harita Teması', style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 8),
Consumer(builder: (context, ref, _) {
  final themesAsync = ref.watch(tileThemesAdminProvider);
  return themesAsync.when(
    loading: () => const LinearProgressIndicator(),
    error: (e, _) => Text('Tema yüklenemedi: $e'),
    data: (themes) {
      return DropdownButtonFormField<String?>(
        value: _pathTileThemeId,
        decoration: const InputDecoration(
          hintText: 'Tema seçin (ünite haritası arka planı)',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tema yok (basit liste)')),
          ...themes.map((t) => DropdownMenuItem<String?>(
                value: t['id'] as String,
                child: Text(t['name'] as String? ?? ''),
              )),
        ],
        onChanged: (v) => setState(() => _pathTileThemeId = v),
      );
    },
  );
}),
```

Add import: `import '../../tiles/screens/tile_theme_list_screen.dart';`

- [ ] **Step 2: Add path-level theme to assignment editor**

In assignment_screen.dart, in `_ScopeLearningPathData`:
- Add field: `String? tileThemeId;`

In `_loadScopeAssignments`, when creating `_ScopeLearningPathData`:
- Add: `tileThemeId: pathRow['tile_theme_id'] as String?,`

In the scope path header/card area, add a similar dropdown that updates `path.tileThemeId` and persists via:
```dart
supabase.from(DbTables.scopeLearningPaths)
    .update({'tile_theme_id': themeId})
    .eq('id', path.id!);
```

Update the SELECT query for scope_learning_paths to include `tile_theme_id`:
```dart
.select('id, name, template_id, sort_order, sequential_lock, books_exempt_from_lock, unit_gate, tile_theme_id')
```

- [ ] **Step 3: Verify**

```bash
dart analyze owlio_admin/lib/features/templates/screens/template_edit_screen.dart owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart
```

- [ ] **Step 4: Commit**

```bash
git add owlio_admin/lib/features/templates/screens/template_edit_screen.dart owlio_admin/lib/features/learning_path_assignments/screens/assignment_screen.dart
git commit -m "feat: add path-level tile theme dropdown to template and assignment editors"
```

---

### Task 8: Full verification

**Files:**
- All modified/created files

- [ ] **Step 1: Full analysis**

```bash
dart analyze lib/
dart analyze owlio_admin/lib/
```

- [ ] **Step 2: Test flow in browser**

```bash
flutter run -d chrome
```

Test:
- Login as student with 1 learning path → should go directly to unit map
- Unit map shows units as nodes (or cards if no theme)
- Tap unit → unit detail screen with items
- Back button returns to unit map

- [ ] **Step 3: Test admin**

```bash
cd owlio_admin && flutter run -d chrome
```

Test:
- Template editor → "Harita Teması" dropdown visible
- Assignment editor → path-level theme dropdown visible
- Assign a tile theme to a path → student sees tile background on unit map

- [ ] **Step 4: Commit if fixes needed**

```bash
git add -A
git commit -m "fix: resolve issues found during verification"
```
