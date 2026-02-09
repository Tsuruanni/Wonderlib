import 'dart:math';
import 'dart:ui' as ui;

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

    // We'll collect points for the background path here
    final pathPoints = <Offset>[];
    // Helper to add point
    void addPathPoint(double centerX, double currentY) {
       pathPoints.add(Offset(centerX, currentY));
    }

    List<double>? prevNodeCenterXs;

    for (int unitIdx = 0; unitIdx < units.length; unitIdx++) {
      final unit = units[unitIdx];
      final isUnitLocked = unitIdx > 0 && !units[unitIdx - 1].isAllComplete;
      final isUnitComplete = unit.isAllComplete && !isUnitLocked;

      // --- Unit banner (centered) ---
      final unitCenterXs = [screenWidth / 2];
      
      // Add path point for Unit Header
      addPathPoint(unitCenterXs[0], y + 28); // +28 is half of 56 height

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
            isLocked: isUnitLocked,
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
        
         // Add path point for this row
        if (currentNodeCenterXs.isNotEmpty) {
           addPathPoint(currentNodeCenterXs[0], y + 40 + 36); // + middle of connector + row height/2
        }

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

      // --- Flipbook Node (NEW) ---
      final flipbookCenterXs = _nodeCenterXs(
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
      );
      if (flipbookCenterXs.isNotEmpty) {
           addPathPoint(flipbookCenterXs[0], y + 36 + 45); // + half height (90/2)
      }

      if (prevNodeCenterXs != null) {
        connectors.add(
          Positioned(
            top: y,
            left: 0,
            right: 0,
            child: _FanConnector(
              startXs: prevNodeCenterXs,
              endXs: flipbookCenterXs,
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
          child: _FlipbookNode(globalRowIndex: globalRowIndex),
        ),
      );
      y += 80; // Reduced spacing for smaller flipbook
      prevNodeCenterXs = flipbookCenterXs;
      globalRowIndex++;

      // --- Game node (after word rows) ---
      final gameCenterXs = _nodeCenterXs(
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
      );
      if (gameCenterXs.isNotEmpty) {
           addPathPoint(gameCenterXs[0], y + 36 + 100);
      }
      
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
      y += 150;
      prevNodeCenterXs = gameCenterXs;
      globalRowIndex++;

      // --- Treasure chest (after game node) ---
      final treasureCenterXs = _nodeCenterXs(
        globalRowIndex: globalRowIndex,
        screenWidth: screenWidth,
      );
      if (treasureCenterXs.isNotEmpty) {
          addPathPoint(treasureCenterXs[0], y + 36 + 50);
      }

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
          children: [
            // Background Path
            Positioned.fill(
              child: CustomPaint(
                painter: _PathBackgroundPainter(points: pathPoints),
              ),
            ),
            
            // Connectors (Lines between nodes)
            ...connectors,
            
            // Nodes (Buttons, Banners, etc)
            ...nodes,
          ],
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

class _PathBackgroundPainter extends CustomPainter {
  final List<Offset> points;
  
  _PathBackgroundPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final pathColor = AppColors.path;
    final borderColor = AppColors.pathBorder;
    const baseWidth = 140.0;
    const stepSize = 10.0; // Finer steps for smoother sine waves

    // 1. Construct the base spline (centerline)
    final centerPath = Path();
    centerPath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final cp1 = Offset(p1.dx, p1.dy + (p2.dy - p1.dy) / 2);
      final cp2 = Offset(p2.dx, p2.dy - (p2.dy - p1.dy) / 2);
      centerPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    // 2. Sample the path to generate organic edges based on deterministic noise
    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    final metrics = centerPath.computeMetrics();
    for (final metric in metrics) {
      for (double d = 0; d < metric.length; d += stepSize) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) continue;

        final pos = tangent.position;
        // Normal vector (perpendicular to tangent)
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        
        // Deterministic noise based on position 'd'
        // Combining multiple sine waves creates a natural, non-repeating "wobble"
        // that is stable across frames (no flicker).
        final noise = sin(d * 0.05) * 4.0 + 
                      cos(d * 0.13) * 2.0 + 
                      sin(d * 0.3) * 1.5;
        
        final currentWidth = baseWidth + noise;
        final halfWidth = currentWidth / 2;

        leftPoints.add(pos + normal * halfWidth);
        rightPoints.add(pos - normal * halfWidth);
      }
      
      // Close the loop at the very end
      final tangent = metric.getTangentForOffset(metric.length);
       if (tangent != null) {
        final pos = tangent.position;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        // Calculate noise for the end point too
        final d = metric.length;
        final noise = sin(d * 0.05) * 4.0 + 
                      cos(d * 0.13) * 2.0 + 
                      sin(d * 0.3) * 1.5;

        final currentWidth = baseWidth + noise;
        final halfWidth = currentWidth / 2;
        
        leftPoints.add(pos + normal * halfWidth);
        rightPoints.add(pos - normal * halfWidth);
      }
    }

    // 3. Construct the organic closed path
    final organicPath = Path();
    if (leftPoints.isNotEmpty) {
      organicPath.moveTo(leftPoints.first.dx, leftPoints.first.dy);
      
      for (int i = 0; i < leftPoints.length - 1; i++) {
        final p1 = leftPoints[i];
        final p2 = leftPoints[i + 1];
        organicPath.quadraticBezierTo(p1.dx, p1.dy, (p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      }
      organicPath.lineTo(leftPoints.last.dx, leftPoints.last.dy);
      organicPath.lineTo(rightPoints.last.dx, rightPoints.last.dy);

      for (int i = rightPoints.length - 1; i > 0; i--) {
        final p1 = rightPoints[i];
        final p2 = rightPoints[i - 1];
        organicPath.quadraticBezierTo(p1.dx, p1.dy, (p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      }
      organicPath.lineTo(rightPoints.first.dx, rightPoints.first.dy);
      
      organicPath.close();
    }

    // 4. Paint it
    final fillPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0 // Reduced from 14.0 for a cleaner look
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(organicPath, borderPaint);
    canvas.drawPath(organicPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _PathBackgroundPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (points[i] != oldDelegate.points[i]) return true;
    }
    return false;
  }
}

/// Centered unit banner — a wide pill with unit number and name.
/// No 3D shadow (flat) so it's visually distinct from clickable nodes.
class _UnitBanner extends StatelessWidget {
  const _UnitBanner({
    required this.unit,
    required this.unitIndex,
    this.isLocked = false,
  });

  final VocabularyUnit unit;
  final int unitIndex;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final color = isLocked ? AppColors.neutral : unit.parsedColor;

    return SizedBox(
      height: 56,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2), // Added white border for pop
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2), // Darker, general shadow for contrast
                blurRadius: 8,
                offset: const Offset(0, 4),
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
                  color: Colors.white.withValues(alpha: 0.9),
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
              if (isLocked) ...[
                 const SizedBox(width: 8),
                 const Icon(Icons.lock, color: Colors.white, size: 16),
              ],
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
        ],
      ),
    );
  }

  double _nodeLeft({
    required double screenWidth,
    required LabelPosition labelPosition,
  }) {
    const sideWidth = 286.0; // 140 label + 70 gap + 76 node
    final centerX = screenWidth / 2;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;
    final rowCenterX = centerX + sineOffset;

    final x = rowCenterX.clamp(sideWidth / 2, screenWidth - sideWidth / 2);
    double leftEdge;
    if (labelPosition == LabelPosition.right) {
      // [node 76px][70px gap][label 140px]
      // Node center is at 38px
      leftEdge = x - 38;
    } else {
      // [label 140px][70px gap][node 76px]
      // Node center is at 140 + 70 + 38 = 248px
      leftEdge = x - 248;
    }
    return leftEdge.clamp(0, screenWidth - sideWidth);
  }
}

/// Game node placeholder on the learning path.
/// Just the icon centered on the path.
class _GameNode extends StatelessWidget {
  const _GameNode({required this.globalRowIndex});

  final int globalRowIndex;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;

    const sideWidth = 200.0; // Increased to 200 for Lottie (2x)
    final centerX = screenWidth / 2;
    final rowCenterX = centerX + sineOffset;
    
    // Calculate simple centered position based on path
    double leftEdge = rowCenterX - (sideWidth / 2);
    leftEdge = leftEdge.clamp(0, screenWidth - sideWidth);

    return SizedBox(
      height: 200, // Increased height to 200
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: leftEdge,
            top: 0, // Centered vertically in the 200px box
            child: Lottie.asset(
              'assets/animations/game_controller.json',
              width: 200,
              fit: BoxFit.contain,
              repeat: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flipbook animation node
class _FlipbookNode extends StatelessWidget {
  const _FlipbookNode({required this.globalRowIndex});

  final int globalRowIndex;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final amplitude = screenWidth * 0.2;
    final sineOffset = sin(globalRowIndex * pi / 3) * amplitude;

    const sideWidth = 100.0; // Reduced from 200
    final centerX = screenWidth / 2;
    final rowCenterX = centerX + sineOffset;
    
    double leftEdge = rowCenterX - (sideWidth / 2);
    leftEdge = leftEdge.clamp(0, screenWidth - sideWidth);

    return SizedBox(
      height: 90, // Reduced from 180
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: leftEdge,
            top: 0,
            child: Lottie.asset(
              'assets/animations/flipbook.json',
              width: 100, // Reduced from 200
              height: 90, // Reduced from 180
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Treasure chest node between units.
/// Just the animation centered on the path.
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

    const sideWidth = 100.0; // Lottie width
    final centerX = screenWidth / 2;
    final rowCenterX = centerX + sineOffset;
    
    double leftEdge = rowCenterX - (sideWidth / 2);
    leftEdge = leftEdge.clamp(0, screenWidth - sideWidth);

    final circle = Lottie.asset(
      'assets/animations/Treasure Box Animation.json',
      width: 100,
      fit: BoxFit.contain,
    );

    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: leftEdge,
            top: -15,
            child: circle,
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
          color: isCompleted ? AppColors.primary : AppColors.neutral.withValues(alpha: 0.5), // Lighter neutral for brown bg
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
      ..strokeWidth = 3 // Slightly thinner to look like a pen stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pairs = _computePairs();
    
    for (final (sx, ex) in pairs) {
      // 1. Create base smooth path
      final basePath = Path()
        ..moveTo(sx, 0)
        ..cubicTo(
          sx, size.height * 0.65,
          ex, size.height * 0.35,
          ex, size.height,
        );

      // 2. Re-sample with jitter for hand-drawn look
      final organicPath = Path();
      final metrics = basePath.computeMetrics();
      
      bool firstPoint = true;

      for (final metric in metrics) {
        // Step size determines how "high frequency" the wobble is
        const stepSize = 5.0; 
        for (double d = 0; d < metric.length; d += stepSize) {
          final tangent = metric.getTangentForOffset(d);
          if (tangent == null) continue;

          final pos = tangent.position;
          final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
          
          // Deterministic noise for stability (scaled down for thin lines)
          final noise = sin(d * 0.1) * 1.5 + 
                        cos(d * 0.25) * 1.0;
          
          final jitteredPos = pos + normal * noise;

          if (firstPoint) {
            organicPath.moveTo(jitteredPos.dx, jitteredPos.dy);
            firstPoint = false;
          } else {
            organicPath.lineTo(jitteredPos.dx, jitteredPos.dy);
          }
        }
        
        // Connect to the exact end point (or close to it with jitter)
        final tangent = metric.getTangentForOffset(metric.length);
        if (tangent != null) {
           final d = metric.length;
           final pos = tangent.position;
           final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
           final noise = sin(d * 0.1) * 1.5 + cos(d * 0.25) * 1.0;
           final jitteredPos = pos + normal * noise;
           organicPath.lineTo(jitteredPos.dx, jitteredPos.dy);
        }
      }

      canvas.drawPath(organicPath, paint);
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
