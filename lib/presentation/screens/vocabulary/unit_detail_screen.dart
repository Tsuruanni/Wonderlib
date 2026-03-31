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
import '../../widgets/common/top_navbar.dart';
import '../../widgets/learning_path/map_tile.dart';
import '../../widgets/learning_path/node_progress_sheet.dart';
import '../../widgets/learning_path/path_node.dart';
import '../../widgets/learning_path/tile_themes.dart';

/// Displays a single unit's items (word lists, books, game, treasure, review)
/// on a tile-based map. Same rendering as LearningPathView but for one unit.
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
            child: Text(
              'Could not load unit',
              style: GoogleFonts.nunito(color: AppColors.neutralText),
            ),
          ),
          data: (allUnits) {
            final path = paths.where((p) => p.id == pathId).firstOrNull;
            if (path == null || unitIdx >= path.units.length) {
              return const Center(child: Text('Unit not found'));
            }

            final lpUnit = path.units[unitIdx];
            final pathUnits = allUnits.where((pu) => pu.pathId == pathId).toList();
            final unitData = unitIdx < pathUnits.length ? pathUnits[unitIdx] : null;
            if (unitData == null) {
              return const Center(child: Text('Unit data not found'));
            }

            return Column(
              children: [
                const TopNavbar(),
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

    // Resolve unit-level theme
    final theme = _resolveTheme(unitData.tileThemeId, unitIdx, dbThemes);

    // Build node data — same logic as LearningPathView
    final locks = calculateLocks(
      items: unitData.items,
      sequentialLock: unitData.sequentialLock,
      booksExemptFromLock: unitData.booksExemptFromLock,
      isUnitLocked: false, // Already inside the unit
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
              context.push(AppRoutes.vocabularySessionPath(wl.wordList.id));
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
