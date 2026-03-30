import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Clamp width to kTileWidth max — don't stretch beyond design size
        final w = constraints.maxWidth.clamp(0.0, kTileWidth);
        final scale = w < kTileWidth ? w / kTileWidth : 1.0;
        final h = theme.height * scale;

        // On wide screens, add rounded corners so tile doesn't look flat
        final isWide = constraints.maxWidth > kTileWidth;
        final radius = isWide ? BorderRadius.circular(24.0) : BorderRadius.zero;

        Widget tile = Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Background: fills scaled area
            Positioned.fill(
              child: theme.imageUrl != null
                  ? Image.network(
                      theme.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _PlaceholderBackground(colors: theme.fallbackColors),
                    )
                  : _PlaceholderBackground(colors: theme.fallbackColors),
            ),
            // Nodes: scaled positions, original widget size
            for (int i = 0; i < nodes.length; i++)
              if (i < theme.nodePositions.length)
                _PositionedNode(
                  position: theme.nodePositions[i],
                  data: nodes[i],
                  tileWidth: w,
                  tileHeight: h,
                ),
          ],
        );

        if (isWide) {
          tile = ClipRRect(
            borderRadius: radius,
            child: tile,
          );
        }

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: tile,
          ),
        );
      },
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
  });

  final Offset position;
  final MapTileNodeData data;
  final double tileWidth;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    final nodeX = position.dx * tileWidth;
    final nodeY = position.dy * tileHeight;
    final labelOnRight = position.dx < 0.5;

    return Positioned(
      left: nodeX - 32, // center 64px wide node circle
      top: nodeY - 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label on left side
          if (!labelOnRight && data.label != null)
            _SideLabel(label: data.label!, isLocked: data.state == NodeState.locked),
          if (!labelOnRight && data.label != null)
            const SizedBox(width: 8),
          // Node column (START bubble + circle + stars)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.state == NodeState.active) ...[
                const StartBubble(),
                const SizedBox(height: 4),
              ],
              PathNode(
                type: data.type,
                state: data.state,
                onTap: data.onTap,
                starCount: data.starCount,
              ),
            ],
          ),
          // Label on right side
          if (labelOnRight && data.label != null)
            const SizedBox(width: 8),
          if (labelOnRight && data.label != null)
            _SideLabel(label: data.label!, isLocked: data.state == NodeState.locked),
        ],
      ),
    );
  }
}

/// Label displayed beside a node with semi-transparent white background.
class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.label, required this.isLocked});

  final String label;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isLocked ? AppColors.neutralText : AppColors.black,
        ),
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
