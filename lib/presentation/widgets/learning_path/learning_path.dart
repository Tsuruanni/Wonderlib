import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/tile_theme_provider.dart';
import '../../providers/vocabulary_provider.dart';
import 'map_tile.dart';
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
          style: AppTextStyles.bodyLarge(color: AppColors.neutralText),
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

  Widget _buildTiles(
    BuildContext context,
    WidgetRef ref,
    List<PathUnitData> units,
  ) {
    final settings = ref.watch(systemSettingsProvider).valueOrNull;
    final star3 = settings?.starRating3 ?? 90;
    final star2 = settings?.starRating2 ?? 70;
    final star1 = settings?.starRating1 ?? 50;

    final wordsToday =
        ref.watch(wordsStartedTodayFromListsProvider).valueOrNull ?? 0;
    final canStartNewList = wordsToday < dailyWordListLimit;

    final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

    // Build a set of assigned resource IDs for quick lookup
    final activeAssignments = ref.watch(activeAssignmentsProvider).valueOrNull ?? [];
    final assignedWordListIds = <String>{};
    final assignedBookIds = <String>{};
    final assignedUnitIds = <String>{};
    for (final a in activeAssignments) {
      if (a.wordListId != null) assignedWordListIds.add(a.wordListId!);
      if (a.bookId != null) assignedBookIds.add(a.bookId!);
      if (a.unitId != null) assignedUnitIds.add(a.unitId!);
    }

    final children = <Widget>[];
    bool foundActive = false;

    for (int unitIdx = 0; unitIdx < units.length; unitIdx++) {
      final unit = units[unitIdx];
      final isUnitLocked = unit.unitGate && unitIdx > 0 && !units[unitIdx - 1].isAllComplete;

      // Unit divider
      children.add(
        UnitDivider(
          unitIndex: unitIdx,
          unitName: unit.unit.name,
          unitIcon: unit.unit.icon,
          isLocked: isUnitLocked,
        ),
      );

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
            unit: unit,
            star3: star3,
            star2: star2,
            star1: star1,
            canStartNewList: canStartNewList,
            isFirstItem: itemIdx == 0,
            assignedWordListIds: assignedWordListIds,
            assignedBookIds: assignedBookIds,
            assignedUnitIds: assignedUnitIds,
          ),
        );
      }

      // Map tile
      final theme = _resolveTheme(unit, unitIdx, dbThemes);
      children.add(MapTile(theme: theme, nodes: tileNodes));
    }

    return Column(children: children);
  }

  TileTheme _resolveTheme(PathUnitData unit, int unitIdx, List<TileThemeEntity> dbThemes) {
    if (unit.tileThemeId != null && dbThemes.isNotEmpty) {
      final match = dbThemes.where((t) => t.id == unit.tileThemeId).firstOrNull;
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
    return tileThemeForUnit(unitIdx);
  }

  static Color _parseHex(String hex) {
    if (hex.length < 7) return const Color(0xFF58CC02);
    try {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF58CC02);
    }
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
    required bool isFirstItem,
    required Set<String> assignedWordListIds,
    required Set<String> assignedBookIds,
    required Set<String> assignedUnitIds,
  }) {
    // Check if the entire unit is assigned
    final unitAssigned = assignedUnitIds.contains(unit.unit.id);

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
          hasAssignment: unitAssigned || assignedWordListIds.contains(wl.wordList.id),
          onTap: () => context.push(AppRoutes.vocabularySessionPath(wl.wordList.id)),
        );

      case PathBookItem(:final bookWithProgress):
        return MapTileNodeData(
          type: NodeType.book,
          state: state,
          label: bookWithProgress.book.title,
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned || assignedBookIds.contains(bookWithProgress.bookId),
          onTap: () =>
              context.push(AppRoutes.bookDetailPath(bookWithProgress.bookId)),
        );

      case PathGameItem():
        return MapTileNodeData(
          type: NodeType.game,
          state: state,
          label: 'Game',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: () => completePathNode(ref, unit.unit.id, 'game'),
        );

      case PathTreasureItem(:final itemId):
        return MapTileNodeData(
          type: NodeType.treasure,
          state: state,
          label: 'Treasure',
          isFirstItem: isFirstItem,
          hasAssignment: unitAssigned,
          onTap: state == NodeState.completed
              ? null
              : () => context.push(AppRoutes.treasureWheelPath(unit.unit.id, itemId)),
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
          Icon(
            Icons.route_rounded,
            size: 48,
            color: AppColors.neutralText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No learning path yet',
            style: AppTextStyles.titleMedium(color: AppColors.neutralText).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your teacher will assign one soon!',
            style: AppTextStyles.bodyMedium(color: AppColors.neutralText.withValues(alpha: 0.7)).copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
