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
            // Labels (behind nodes so they don't overlap circles)
            for (int i = 0; i < nodes.length; i++)
              if (i < theme.nodePositions.length && nodes[i].label != null)
                _buildLabel(theme.nodePositions[i], nodes[i], w, h),
            // Nodes: scaled positions, original widget size
            for (int i = 0; i < nodes.length; i++)
              if (i < theme.nodePositions.length)
                _buildNode(theme.nodePositions[i], nodes[i], h),
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

const _nodeSize = 64.0;

/// Build a Positioned node circle (+ START bubble + stars).
Positioned _buildNode(Offset pos, MapTileNodeData data, double tileH) {
    // Use kTileWidth for X so node stays fixed regardless of screen width
    final nodeX = pos.dx * kTileWidth;
    final nodeY = pos.dy * tileH;

    return Positioned(
      left: nodeX - _nodeSize / 2,
      top: nodeY - _nodeSize / 2,
      child: Column(
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
    );
  }

/// Build a Positioned label beside the node.
Positioned _buildLabel(
      Offset pos, MapTileNodeData data, double tileW, double tileH) {
    final nodeX = pos.dx * kTileWidth;
    final nodeY = pos.dy * tileH;
    final labelOnRight = pos.dx < 0.5;

    return Positioned(
      left: labelOnRight ? nodeX + _nodeSize / 2 + 4 : null,
      right: labelOnRight ? null : tileW - nodeX + _nodeSize / 2 + 4,
      top: nodeY - 12,
      child: _SideLabel(
        label: data.label!,
        isLocked: data.state == NodeState.locked,
      ),
    );
  }

/// Label displayed beside a node with semi-transparent white background.
class _SideLabel extends StatelessWidget {
  const _SideLabel({required this.label, required this.isLocked});

  final String label;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: isLocked ? AppColors.neutralText : AppColors.primary,
          letterSpacing: 0.5,
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
