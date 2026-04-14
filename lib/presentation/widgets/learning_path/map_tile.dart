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
    this.unitNumber,
    this.totalSessions,
    this.bestAccuracy,
    this.bestScore,
    this.isFirstItem = false,
    this.hasAssignment = false,
  });

  final NodeType type;
  final NodeState state;
  final String? label;
  final VoidCallback? onTap;
  final int starCount;
  final int? unitNumber;

  /// Progress stats — shown in popup card when available.
  final int? totalSessions;
  final double? bestAccuracy;
  final int? bestScore;

  /// True when this is the first item in the unit (index 0).
  final bool isFirstItem;

  /// True when this node has an active assignment from the teacher.
  final bool hasAssignment;
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

  /// Nodes render 30% smaller on mobile (< 600px).
  static const _mobileNodeScale = 0.7;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final nodeScale = screenWidth < 600 ? _mobileNodeScale : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill available width; scale everything relative to design width
        final w = constraints.maxWidth;
        final scale = w / kTileWidth;
        final h = theme.height * scale;

        return SizedBox(
          width: w,
          height: h,
          child: ClipRect(
            child: theme.imageUrl != null
                ? Image.network(
                    theme.imageUrl!,
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) {
                        return _TileContent(
                          background: child,
                          nodes: nodes,
                          theme: theme,
                          tileWidth: w,
                          tileHeight: h,
                          nodeScale: nodeScale,
                        );
                      }
                      final loaded = frame != null;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: loaded
                            ? _TileContent(
                                key: const ValueKey('loaded'),
                                background: child,
                                nodes: nodes,
                                theme: theme,
                                tileWidth: w,
                                tileHeight: h,
                                nodeScale: nodeScale,
                              )
                            : Container(
                                key: const ValueKey('loading'),
                                color: theme.fallbackColors.isNotEmpty
                                    ? theme.fallbackColors.first
                                    : Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _TileContent(
                      background: _PlaceholderBackground(colors: theme.fallbackColors),
                      nodes: nodes,
                      theme: theme,
                      tileWidth: w,
                      tileHeight: h,
                      nodeScale: nodeScale,
                    ),
                  )
                : _TileContent(
                    background: _PlaceholderBackground(colors: theme.fallbackColors),
                    nodes: nodes,
                    theme: theme,
                    tileWidth: w,
                    tileHeight: h,
                    nodeScale: nodeScale,
                  ),
          ),
        );
      },
    );
  }
}

/// Combines the background image with positioned nodes in a Stack.
/// Used to show nodes only after the background has loaded.
class _TileContent extends StatelessWidget {
  const _TileContent({
    super.key,
    required this.background,
    required this.nodes,
    required this.theme,
    required this.tileWidth,
    required this.tileHeight,
    required this.nodeScale,
  });

  final Widget background;
  final List<MapTileNodeData> nodes;
  final TileTheme theme;
  final double tileWidth;
  final double tileHeight;
  final double nodeScale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: background),
        for (int i = 0; i < nodes.length; i++)
          if (i < theme.nodePositions.length)
            _PositionedNode(
              position: theme.nodePositions[i],
              data: nodes[i],
              tileWidth: tileWidth,
              tileHeight: tileHeight,
              nodeScale: nodeScale,
            ),
      ],
    );
  }
}

/// A node positioned by percentage coordinates within the tile.
class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.position,
    required this.data,
    required this.tileWidth,
    required this.tileHeight,
    this.nodeScale = 1.0,
  });

  final Offset position;
  final MapTileNodeData data;
  final double tileWidth;
  final double tileHeight;
  final double nodeScale;

  @override
  Widget build(BuildContext context) {
    final scaledWidth = PathNode.baseWidth * nodeScale;
    final left = position.dx * tileWidth - scaledWidth / 2;
    final top = position.dy * tileHeight - 40 * nodeScale;

    // Bubble only on detail-page nodes (no unitNumber), not on unit map
    final showBubble =
        data.state == NodeState.active && data.unitNumber == null;
    final bubbleText = data.isFirstItem ? 'START' : 'YOU ARE HERE';

    return Positioned(
      left: left,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBubble) ...[
            StartBubble(scale: nodeScale, text: bubbleText),
            SizedBox(height: 4 * nodeScale),
          ],
          PathNode(
            type: data.type,
            state: data.state,
            label: data.label,
            onTap: data.onTap,
            starCount: data.starCount,
            unitNumber: data.unitNumber,
            scale: nodeScale,
            totalSessions: data.totalSessions,
            bestAccuracy: data.bestAccuracy,
            bestScore: data.bestScore,
            hasAssignment: data.hasAssignment,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }
}
