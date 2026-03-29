import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Draws the organic background path behind all nodes.
/// Uses cubic splines + deterministic sine-wave noise for a natural wobble.
class PathBackgroundPainter extends CustomPainter {
  final List<Offset> points;

  PathBackgroundPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final pathColor = AppColors.path;
    final borderColor = AppColors.pathBorder;
    const baseWidth = 100.0;
    const stepSize = 10.0;

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
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);

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
        organicPath.quadraticBezierTo(
            p1.dx, p1.dy, (p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      }
      organicPath.lineTo(leftPoints.last.dx, leftPoints.last.dy);
      organicPath.lineTo(rightPoints.last.dx, rightPoints.last.dy);

      for (int i = rightPoints.length - 1; i > 0; i--) {
        final p1 = rightPoints[i];
        final p2 = rightPoints[i - 1];
        organicPath.quadraticBezierTo(
            p1.dx, p1.dy, (p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
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
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(organicPath, borderPaint);
    canvas.drawPath(organicPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant PathBackgroundPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (points[i] != oldDelegate.points[i]) return true;
    }
    return false;
  }
}

/// Fan connector between two path rows.
/// Draws Bezier curves handling 1→1, 1→N (fan-out), N→1 (fan-in), and N→M.
class PathConnector extends StatelessWidget {
  const PathConnector({
    super.key,
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
        painter: _PathConnectorPainter(
          startXs: startXs,
          endXs: endXs,
          color: isCompleted
              ? AppColors.primary
              : AppColors.neutral.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _PathConnectorPainter extends CustomPainter {
  _PathConnectorPainter({
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
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pairs = _computePairs();

    for (final (sx, ex) in pairs) {
      // 1. Create base smooth path
      final basePath = Path()
        ..moveTo(sx, 0)
        ..cubicTo(
          sx,
          size.height * 0.65,
          ex,
          size.height * 0.35,
          ex,
          size.height,
        );

      // 2. Re-sample with jitter for hand-drawn look
      final organicPath = Path();
      final metrics = basePath.computeMetrics();

      bool firstPoint = true;

      for (final metric in metrics) {
        const stepSize = 5.0;
        for (double d = 0; d < metric.length; d += stepSize) {
          final tangent = metric.getTangentForOffset(d);
          if (tangent == null) continue;

          final pos = tangent.position;
          final normal = Offset(-tangent.vector.dy, tangent.vector.dx);

          final noise = sin(d * 0.1) * 1.5 + cos(d * 0.25) * 1.0;

          final jitteredPos = pos + normal * noise;

          if (firstPoint) {
            organicPath.moveTo(jitteredPos.dx, jitteredPos.dy);
            firstPoint = false;
          } else {
            organicPath.lineTo(jitteredPos.dx, jitteredPos.dy);
          }
        }

        // Connect to the exact end point
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

  List<(double, double)> _computePairs() {
    if (startXs.length == 1 && endXs.length == 1) {
      return [(startXs[0], endXs[0])];
    }
    if (startXs.length == 1) {
      return [for (final ex in endXs) (startXs[0], ex)];
    }
    if (endXs.length == 1) {
      return [for (final sx in startXs) (sx, endXs[0])];
    }
    final avgStart = startXs.reduce((a, b) => a + b) / startXs.length;
    return [for (final ex in endXs) (avgStart, ex)];
  }

  @override
  bool shouldRepaint(_PathConnectorPainter oldDelegate) =>
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
