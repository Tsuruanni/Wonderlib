import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../app/router.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final connectors = <Widget>[];
    final nodes = <Widget>[];
    int globalRowIndex = 0;
    bool foundActive = false;
    double y = 0;

    List<double>? prevNodeCenterXs;

    for (int unitIdx = 0; unitIdx < units.length; unitIdx++) {
      final unit = units[unitIdx];
      final isUnitLocked = unitIdx > 0 && !units[unitIdx - 1].isAllComplete;
      final isUnitComplete = unit.isAllComplete && !isUnitLocked;

      // --- Unit banner (centered) ---
      final unitCenterXs = [screenWidth / 2];

      if (prevNodeCenterXs != null) {
        final prevCompleted = !isUnitLocked && unitIdx > 0 &&
            units[unitIdx - 1].isAllComplete;
        connectors.add(
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: _FanConnector(
              startXs: prevNodeCenterXs,
              endXs: unitCenterXs,
              isCompleted: prevCompleted,
            ),
          ),
        );
        y += 36;
      }

      nodes.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          child: _UnitBanner(
            unit: unit.unit,
            unitIndex: unitIdx + 1,
          ),
        ),
      );
      y += 56;

      prevNodeCenterXs = unitCenterXs;
      globalRowIndex++;

      // --- Word rows ---
      for (int rowIdx = 0; rowIdx < unit.rows.length; rowIdx++) {
        final row = unit.rows[rowIdx];

        final currentNodeCenterXs = _nodeCenterXs(
          globalRowIndex: globalRowIndex,
          screenWidth: screenWidth,
        );

        if (prevNodeCenterXs != null) {
          bool prevCompleted;
          if (isUnitLocked) {
            prevCompleted = false;
          } else if (rowIdx == 0) {
            prevCompleted = unitIdx > 0
                ? units[unitIdx - 1].isAllComplete
                : false;
          } else {
            prevCompleted = units[unitIdx].rows[rowIdx - 1].items.every(
              (i) => i.isComplete,
            );
          }
          connectors.add(
            Positioned(
              top: y,
              left: 0,
              right: 0,
              child: _FanConnector(
                startXs: prevNodeCenterXs,
                endXs: currentNodeCenterXs,
                isCompleted: prevCompleted,
              ),
            ),
          );
          y += 36;
        }

        // Active detection only for unlocked units
        final activeFlags = <bool>[];
        for (final item in row.items) {
          if (!isUnitLocked && !foundActive && !item.isComplete) {
            activeFlags.add(true);
            foundActive = true;
          } else {
            activeFlags.add(false);
          }
        }

        nodes.add(
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: _PathRow(
              row: row,
              globalRowIndex: globalRowIndex,
              unitColor: unit.unit.parsedColor,
              activeFlags: activeFlags,
              isLocked: isUnitLocked,
            ),
          ),
        );
        y += 80.0;

        prevNodeCenterXs = currentNodeCenterXs;
        globalRowIndex++;
      }

      // --- Game node (after word rows) ---
      final gameCenterXs = _nodeCenterXs(
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
      );
      if (prevNodeCenterXs != null) {
        connectors.add(
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: _FanConnector(
              startXs: prevNodeCenterXs,
              endXs: gameCenterXs,
              isCompleted: false,
            ),
          ),
        );
        y += 36;
      }
      nodes.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          child: _GameNode(globalRowIndex: globalRowIndex),
        ),
      );
      y += 70;
      prevNodeCenterXs = gameCenterXs;
      globalRowIndex++;

      // --- Treasure chest (after game node) ---
      final treasureCenterXs = _nodeCenterXs(
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
      );
      connectors.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          child: _FanConnector(
            startXs: prevNodeCenterXs,
            endXs: treasureCenterXs,
            isCompleted: false,
          ),
        ),
      );
      y += 36;
      nodes.add(
        Positioned(
          top: y,
          left: 0,
          right: 0,
          child: _TreasureChestNode(
            isUnitComplete: isUnitComplete,
            globalRowIndex: globalRowIndex,
          ),
        ),
      );
      y += 70;
      prevNodeCenterXs = treasureCenterXs;
      globalRowIndex++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: y,
        child: Stack(
          clipBehavior: Clip.none,
          children: [...connectors, ...nodes],
        ),
      ),
    );
  }

  /// Returns the node center X position for a single-node row.
  List<double> _nodeCenterXs({
    required int globalRowIndex,
    required double screenWidth,
  }) {
    const nodeWidth = 92.0;
    final centerX = screenWidth / 2;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final rowCenterX = centerX + sineOffset;
    return [rowCenterX.clamp(nodeWidth / 2, screenWidth - nodeWidth / 2)];
  }
}

/// Centered unit banner — a wide pill with unit number and name.
/// No 3D shadow (flat) so it's visually distinct from clickable nodes.
class _UnitBanner extends StatelessWidget {
  const _UnitBanner({
    required this.unit,
    required this.unitIndex,
  });

  final VocabularyUnit unit;
  final int unitIndex;

  @override
  Widget build(BuildContext context) {
    final color = unit.parsedColor;

    return SizedBox(
      height: 56,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UNIT $unitIndex',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unit.name,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Positions a single PathNode in a zigzag pattern with a side label.
class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.row,
    required this.globalRowIndex,
    required this.unitColor,
    required this.activeFlags,
    this.isLocked = false,
  });

  final PathRowData row;
  final int globalRowIndex;
  final Color unitColor;
  final List<bool> activeFlags;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final item = row.items.first;

    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final labelPosition =
        sineOffset > 0 ? LabelPosition.left : LabelPosition.right;
    final isLeft = labelPosition == LabelPosition.left;

    final nodeLeft = _nodeLeft(screenWidth: screenWidth, labelPosition: labelPosition);
    final isActive = activeFlags.isNotEmpty && activeFlags[0];
    final showStart = isActive && !isLocked;

    // START pill on the opposite side of the label.
    // isLeft (label left): [label|node] ... [START] → right of widget
    // !isLeft (label right): [START] ... [node|label] → left of widget
    final startLeft = isLeft ? nodeLeft + 170.0 : nodeLeft - 83.0;

    return SizedBox(
      height: 80.0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: nodeLeft,
            top: 0,
            child: PathNode(
              wordListWithProgress: item,
              unitColor: unitColor,
              isActive: isActive,
              isLocked: isLocked,
              labelPosition: labelPosition,
            ),
          ),
          if (showStart)
            Positioned(
              left: startLeft,
              top: 20,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(AppRoutes.vocabularyListPath(item.wordList.id)),
                child: _startPill(),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _startPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: AppColors.primaryDark,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'START',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  double _nodeLeft({
    required double screenWidth,
    required LabelPosition labelPosition,
  }) {
    const sideWidth = 164.0; // 80 label + 8 gap + 76 node
    final centerX = screenWidth / 2;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final rowCenterX = centerX + sineOffset;

    final x = rowCenterX.clamp(sideWidth / 2, screenWidth - sideWidth / 2);
    double leftEdge;
    if (labelPosition == LabelPosition.right) {
      // [node 76px][8px gap][label 80px] — circle center at 38px from left
      leftEdge = x - 38;
    } else {
      // [label 80px][8px gap][node 76px] — circle center at 126px from left
      leftEdge = x - 126;
    }
    return leftEdge.clamp(0, screenWidth - sideWidth);
  }
}

/// Game node placeholder on the learning path.
/// Greyed out with "Coming Soon" label — no navigation.
class _GameNode extends StatelessWidget {
  const _GameNode({required this.globalRowIndex});

  final int globalRowIndex;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final labelPos =
        sineOffset > 0 ? LabelPosition.left : LabelPosition.right;

    const sideWidth = 164.0;
    final centerX = screenWidth / 2;
    final rowCenterX = centerX + sineOffset;
    final x = rowCenterX.clamp(sideWidth / 2, screenWidth - sideWidth / 2);
    double leftEdge;
    if (labelPos == LabelPosition.right) {
      leftEdge = x - 38;
    } else {
      leftEdge = x - 126;
    }
    leftEdge = leftEdge.clamp(0, screenWidth - sideWidth);

    final circle = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.neutral,
        boxShadow: [
          BoxShadow(
            color: AppColors.neutralDark.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );

    final isLeft = labelPos == LabelPosition.left;
    final label = SizedBox(
      width: 80,
      child: Text(
        'Coming Soon',
        textAlign: isLeft ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.neutralText,
        ),
      ),
    );

    final rowChildren = isLeft
        ? [label, const SizedBox(width: 8), circle]
        : [circle, const SizedBox(width: 8), label];

    return SizedBox(
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: leftEdge,
            top: 0,
            child: SizedBox(
              width: 164,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rowChildren,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Treasure chest node between units.
/// Closed when unit incomplete, open with sparkle when complete.
class _TreasureChestNode extends StatelessWidget {
  const _TreasureChestNode({
    required this.isUnitComplete,
    required this.globalRowIndex,
  });

  final bool isUnitComplete;
  final int globalRowIndex;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final labelPos =
        sineOffset > 0 ? LabelPosition.left : LabelPosition.right;

    const sideWidth = 164.0;
    final centerX = screenWidth / 2;
    final rowCenterX = centerX + sineOffset;
    final x = rowCenterX.clamp(sideWidth / 2, screenWidth - sideWidth / 2);
    double leftEdge;
    if (labelPos == LabelPosition.right) {
      leftEdge = x - 38;
    } else {
      leftEdge = x - 126;
    }
    leftEdge = leftEdge.clamp(0, screenWidth - sideWidth);

    final circle = Lottie.asset(
      'assets/animations/Treasure Box Animation.json',
      width: 100,
      fit: BoxFit.contain,
    );

    final isLeft = labelPos == LabelPosition.left;
    final label = SizedBox(
      width: 80,
      child: Text(
        isUnitComplete ? 'Reward!' : 'Treasure',
        textAlign: isLeft ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isUnitComplete ? AppColors.black : AppColors.neutralText,
        ),
      ),
    );

    final rowChildren = isLeft
        ? [label, const SizedBox(width: 8), circle]
        : [circle, const SizedBox(width: 8), label];

    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: leftEdge - 20,
            top: -15,
            child: SizedBox(
              width: 200,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rowChildren,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fan connector between two path rows.
/// Draws Bezier curves handling 1→1, 1→N (fan-out), N→1 (fan-in), and N→M.
class _FanConnector extends StatelessWidget {
  const _FanConnector({
    required this.startXs,
    required this.endXs,
    required this.isCompleted,
  });

  final List<double> startXs;
  final List<double> endXs;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 36,
      width: screenWidth,
      child: CustomPaint(
        painter: _FanConnectorPainter(
          startXs: startXs,
          endXs: endXs,
          color: isCompleted ? AppColors.primary : AppColors.neutral,
        ),
      ),
    );
  }
}

class _FanConnectorPainter extends CustomPainter {
  _FanConnectorPainter({
    required this.startXs,
    required this.endXs,
    required this.color,
  });

  final List<double> startXs;
  final List<double> endXs;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pairs = _computePairs();
    for (final (sx, ex) in pairs) {
      final path = Path()
        ..moveTo(sx, 0)
        ..cubicTo(
          sx, size.height * 0.65,
          ex, size.height * 0.35,
          ex, size.height,
        );
      canvas.drawPath(path, paint);
    }
  }

  /// Compute (startX, endX) pairs for each curve to draw.
  List<(double, double)> _computePairs() {
    // 1→1: single curve
    if (startXs.length == 1 && endXs.length == 1) {
      return [(startXs[0], endXs[0])];
    }
    // 1→N (fan-out): one curve from single start to each end
    if (startXs.length == 1) {
      return [for (final ex in endXs) (startXs[0], ex)];
    }
    // N→1 (fan-in): one curve from each start to single end
    if (endXs.length == 1) {
      return [for (final sx in startXs) (sx, endXs[0])];
    }
    // N→M: fan-out from average of starts to each end
    final avgStart = startXs.reduce((a, b) => a + b) / startXs.length;
    return [for (final ex in endXs) (avgStart, ex)];
  }

  @override
  bool shouldRepaint(_FanConnectorPainter oldDelegate) =>
      !_listEquals(startXs, oldDelegate.startXs) ||
      !_listEquals(endXs, oldDelegate.endXs) ||
      color != oldDelegate.color;

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
