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
    return ClipRect(
      child: SizedBox(
        height: theme.height,
        child: OverflowBox(
          maxWidth: kTileWidth,
          minWidth: kTileWidth,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Background — always use placeholder until real assets exist
              Positioned.fill(
                child: _PlaceholderBackground(colors: theme.fallbackColors),
              ),
              // Nodes
              for (int i = 0; i < nodes.length; i++)
                if (i < theme.nodePositions.length)
                  _PositionedNode(
                    position: theme.nodePositions[i],
                    data: nodes[i],
                    tileHeight: theme.height,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A node positioned by percentage coordinates within the tile.
class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.position,
    required this.data,
    required this.tileHeight,
  });

  final Offset position;
  final MapTileNodeData data;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    final left = position.dx * kTileWidth - 70; // center 140px wide node
    final top = position.dy * tileHeight - 40; // approximate vertical center

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
