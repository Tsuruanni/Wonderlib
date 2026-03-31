import 'package:flutter/material.dart';
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
import '../../widgets/common/top_navbar.dart';
import '../../widgets/learning_path/map_tile.dart';
import '../../widgets/learning_path/path_node.dart';
import '../../widgets/learning_path/tile_themes.dart';

/// Displays a single unit's items (word lists, books, game, treasure, review)
/// on a tile-based map. Same rendering as LearningPathView but for one unit.
class UnitDetailScreen extends ConsumerStatefulWidget {
  const UnitDetailScreen({
    super.key,
    required this.pathId,
    required this.unitIdx,
  });

  final String pathId;
  final int unitIdx;

  @override
  ConsumerState<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends ConsumerState<UnitDetailScreen> {
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
            final path = paths.where((p) => p.id == widget.pathId).firstOrNull;
            if (path == null || widget.unitIdx >= path.units.length) {
              return const Center(child: Text('Unit not found'));
            }

            final pathUnits = allUnits.where((pu) => pu.pathId == widget.pathId).toList();
            final unitData = widget.unitIdx < pathUnits.length ? pathUnits[widget.unitIdx] : null;
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
              final theme = _resolveTheme(unitData.tileThemeId, widget.unitIdx, dbThemes);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_hasScrolled && _scrollController.hasClients) {
                  _hasScrolled = true;
                  if (activeIdx! < theme.nodePositions.length) {
                    final nodeY = theme.nodePositions[activeIdx].dy * theme.height;
                    final screenW = MediaQuery.sizeOf(context).width;
                    final scale = screenW / kTileWidth;
                    final scrollTarget = (nodeY * scale - MediaQuery.sizeOf(context).height / 3).clamp(
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

            return Column(
              children: [
                const TopNavbar(),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildUnitTile(context, ref, unitData, dbThemes),
                      ),
                      // Overlay back button on top-left of the tile
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _BackButton(onTap: () => context.pop()),
                      ),
                    ],
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
    final theme = _resolveTheme(unitData.tileThemeId, widget.unitIdx, dbThemes);

    // Build assignment lookup
    final activeAssignments = ref.watch(activeAssignmentsProvider).valueOrNull ?? [];
    final assignedWordListIds = <String>{};
    final assignedBookIds = <String>{};
    final assignedUnitIds = <String>{};
    for (final a in activeAssignments) {
      if (a.wordListId != null) assignedWordListIds.add(a.wordListId!);
      if (a.bookId != null) assignedBookIds.add(a.bookId!);
      if (a.unitId != null) assignedUnitIds.add(a.unitId!);
    }

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
        final stars = wl.starCountWith(star3: star3, star2: star2, star1: star1);
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
          onTap: () => context.push(AppRoutes.bookDetailPath(bookWithProgress.bookId)),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

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
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: AppColors.black,
        ),
      ),
    );
  }
}
