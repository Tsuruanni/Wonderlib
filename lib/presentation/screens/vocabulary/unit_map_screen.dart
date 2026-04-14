import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/tile_theme.dart';
import '../../utils/app_icons.dart';
import '../../providers/tile_theme_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../widgets/learning_path/map_tile.dart';
import '../../widgets/learning_path/path_node.dart';
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
  final _precachedUrls = <String>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Precache tile background images so they're ready when the user
  /// navigates into a unit detail screen.
  void _precacheTileImages(BuildContext context, List<TileThemeEntity> themes) {
    for (final theme in themes) {
      final url = theme.imageUrl;
      if (url != null && _precachedUrls.add(url)) {
        precacheImage(NetworkImage(url), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pathDataAsync = ref.watch(learningPathProvider);
    final paths = ref.watch(userLearningPathsProvider).valueOrNull ?? [];
    final dbThemes = ref.watch(tileThemesProvider).valueOrNull ?? [];

    return pathDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Could not load learning path',
          style: GoogleFonts.nunito(color: AppColors.neutralText),
        ),
      ),
      data: (allUnits) {
        // Precache all tile images in the background
        if (dbThemes.isNotEmpty) {
          _precacheTileImages(context, dbThemes);
        }

        final path = paths.where((p) => p.id == widget.pathId).firstOrNull;
        if (path == null) {
          return Center(
            child: Text(
              'Learning path not found',
              style: GoogleFonts.nunito(color: AppColors.neutralText),
            ),
          );
        }

        // Filter units for this path — pathId guarantees correct ownership + order
        final units = allUnits
            .where((pu) => pu.pathId == widget.pathId)
            .toList();

        // Resolve path-level theme
        final theme = _resolvePathTheme(path.tileThemeId, dbThemes);

        // Find active unit index (first unlocked + incomplete)
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
      },
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
                    AppRoutes.vocabularyPathUnit(widget.pathId, i),
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
              AppIcons.check(size: 28),
            if (isActive)
              const Icon(Icons.play_circle_rounded, color: AppColors.secondary, size: 28),
          ],
        ),
      ),
    );
  }
}
