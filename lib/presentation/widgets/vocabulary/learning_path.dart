import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/vocabulary_unit.dart';
import '../../providers/vocabulary_provider.dart';
import 'path_node.dart';

/// Duolingo-style vertical learning path.
/// Renders units as sections with word list nodes in a zigzag pattern.
class LearningPath extends ConsumerWidget {
  const LearningPath({super.key});

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
          style: GoogleFonts.nunito(color: AppColors.neutralText),
          textAlign: TextAlign.center,
        ),
      ),
      data: (pathUnits) {
        if (pathUnits.isEmpty) return const SizedBox.shrink();
        return _buildPath(context, pathUnits);
      },
    );
  }

  Widget _buildPath(BuildContext context, List<PathUnitData> units) {
    final children = <Widget>[];
    int globalRowIndex = 0;

    for (int unitIdx = 0; unitIdx < units.length; unitIdx++) {
      final unit = units[unitIdx];

      // Unit header banner
      children.add(_UnitHeaderBanner(unit: unit.unit));

      for (int rowIdx = 0; rowIdx < unit.rows.length; rowIdx++) {
        final row = unit.rows[rowIdx];

        // Connector line before each row (except the first row of the first unit)
        if (globalRowIndex > 0) {
          children.add(const _PathConnector());
        }

        children.add(_PathRow(
          row: row,
          globalRowIndex: globalRowIndex,
          unitColor: unit.unit.parsedColor,
        ));

        globalRowIndex++;
      }

      // Space between units
      if (unitIdx < units.length - 1) {
        children.add(const SizedBox(height: 16));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: children),
    );
  }
}

/// Colored banner for a unit section.
class _UnitHeaderBanner extends StatelessWidget {
  const _UnitHeaderBanner({required this.unit});
  final VocabularyUnit unit;

  @override
  Widget build(BuildContext context) {
    final color = unit.parsedColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          if (unit.icon != null) ...[
            Text(unit.icon!, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.name,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                if (unit.description != null)
                  Text(
                    unit.description!,
                    style: GoogleFonts.nunito(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Positions 1-3 PathNodes in a zigzag pattern for one row.
class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.row,
    required this.globalRowIndex,
    required this.unitColor,
  });

  final PathRowData row;
  final int globalRowIndex;
  final Color unitColor;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final items = row.items;
    final itemCount = items.length.clamp(1, 3);

    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < itemCount; i++)
            Positioned(
              left: _nodeLeft(
                globalRowIndex: globalRowIndex,
                itemIndex: i,
                itemCount: itemCount,
                screenWidth: screenWidth,
              ),
              top: 0,
              child: PathNode(
                wordListWithProgress: items[i],
                unitColor: unitColor,
              ),
            ),
        ],
      ),
    );
  }

  double _nodeLeft({
    required int globalRowIndex,
    required int itemIndex,
    required int itemCount,
    required double screenWidth,
  }) {
    const nodeWidth = 88.0;
    const spacing = 16.0;
    final centerX = screenWidth / 2;
    final amplitude = screenWidth * 0.2;

    // Sinusoidal offset for zigzag effect
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final rowCenterX = centerX + sineOffset;

    // Position items within the row
    double x;
    if (itemCount == 1) {
      x = rowCenterX;
    } else if (itemCount == 2) {
      final totalWidth = nodeWidth * 2 + spacing;
      x = rowCenterX - totalWidth / 2 + (nodeWidth + spacing) * itemIndex + nodeWidth / 2;
    } else {
      final totalWidth = nodeWidth * 3 + spacing * 2;
      x = rowCenterX - totalWidth / 2 + (nodeWidth + spacing) * itemIndex + nodeWidth / 2;
    }

    // Clamp to screen bounds
    final minX = nodeWidth / 2;
    final maxX = screenWidth - nodeWidth / 2;
    x = x.clamp(minX, maxX);

    return x - nodeWidth / 2;
  }
}

/// Simple dashed connector line between path rows.
class _PathConnector extends StatelessWidget {
  const _PathConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Center(
        child: CustomPaint(
          size: const Size(2, 24),
          painter: _DashedLinePainter(color: AppColors.neutral),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const dashLength = 5.0;
    const dashGap = 4.0;
    double y = 0;

    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dashLength).clamp(0, size.height)),
        paint,
      );
      y += dashLength + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
