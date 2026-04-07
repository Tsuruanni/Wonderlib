import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/treasure_wheel.dart';

/// Parses a hex color string like '#FF9800' to a Color
Color hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// The spinning wheel widget with pointer, glow ring, and tick indicators
class TreasureWheelWidget extends StatefulWidget {
  const TreasureWheelWidget({
    super.key,
    required this.slices,
    this.onSpinComplete,
  });

  final List<TreasureWheelSlice> slices;
  final VoidCallback? onSpinComplete;

  @override
  State<TreasureWheelWidget> createState() => TreasureWheelWidgetState();
}

class TreasureWheelWidgetState extends State<TreasureWheelWidget>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _spinController;
  late AnimationController _glowController;
  double _currentAngle = 0;
  bool _isIdleSpinning = false;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _idleController.addListener(() {
      if (_isIdleSpinning) {
        setState(() {
          _currentAngle += 0.15;
        });
      }
    });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // Glow pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleController.dispose();
    _spinController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void startIdleSpin() {
    _isIdleSpinning = true;
    _isSpinning = true;
    _idleController.repeat();
  }

  void spinTo(int targetIndex) {
    _isIdleSpinning = false;
    _idleController.stop();

    final sliceCount = widget.slices.length;
    final sliceAngle = 2 * math.pi / sliceCount;

    final random = math.Random();
    final offsetInSlice = (random.nextDouble() * 0.6 + 0.2) * sliceAngle;
    final targetAngle = -(targetIndex * sliceAngle + offsetInSlice);
    final totalRotation = targetAngle - _currentAngle + (5 * 2 * math.pi);

    final tween = Tween<double>(begin: 0, end: totalRotation);
    final curved = CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic);

    _spinController.reset();
    final animation = tween.animate(curved);

    final startAngle = _currentAngle;
    animation.addListener(() {
      setState(() {
        _currentAngle = startAngle + animation.value;
      });
    });

    _spinController.forward().then((_) {
      setState(() => _isSpinning = false);
      widget.onSpinComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 350,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glowOpacity = 0.3 + _glowController.value * 0.4;
              final glowSize = 310.0 + _glowController.value * 10;
              return Container(
                width: glowSize,
                height: glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: glowOpacity),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: glowOpacity * 0.5),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              );
            },
          ),
          // Outer decorative ring with tick marks
          SizedBox(
            width: 310,
            height: 310,
            child: CustomPaint(
              painter: _OuterRingPainter(
                sliceCount: widget.slices.length,
                isSpinning: _isSpinning,
                currentAngle: _currentAngle,
              ),
            ),
          ),
          // Main wheel
          SizedBox(
            width: 280,
            height: 280,
            child: Transform.rotate(
              angle: _currentAngle,
              child: CustomPaint(
                size: const Size(280, 280),
                painter: _WheelPainter(slices: widget.slices),
              ),
            ),
          ),
          // Center jewel
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF176), Color(0xFFFFB300), Color(0xFFFF8F00)],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.diamond, color: Colors.white, size: 20),
          ),
          // Pointer at top
          Positioned(
            top: 0,
            child: _PointerWidget(isSpinning: _isSpinning),
          ),
        ],
      ),
    );
  }
}

/// Outer ring with tick marks for each slice boundary
class _OuterRingPainter extends CustomPainter {
  _OuterRingPainter({
    required this.sliceCount,
    required this.isSpinning,
    required this.currentAngle,
  });

  final int sliceCount;
  final bool isSpinning;
  final double currentAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - 8;

    // Draw outer ring
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = const Color(0xFF2D2D5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    // Draw small LED-like dots around the ring
    const dotCount = 24;
    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * math.pi * i / dotCount) - math.pi / 2;
      final dotRadius = outerRadius - 3;
      final x = center.dx + dotRadius * math.cos(angle);
      final y = center.dy + dotRadius * math.sin(angle);

      // Alternating bright/dim pattern that shifts when spinning
      final isLit = isSpinning
          ? ((i + (currentAngle * 3).round()) % 3 == 0)
          : (i % 2 == 0);

      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = isLit
              ? const Color(0xFFFFD54F)
              : const Color(0xFF5C5C8A),
      );
    }

    // Draw tick marks at slice boundaries
    final sliceAngle = 2 * math.pi / sliceCount;
    for (int i = 0; i < sliceCount; i++) {
      final angle = -math.pi / 2 + i * sliceAngle + currentAngle;
      final outerX = center.dx + (innerRadius + 4) * math.cos(angle);
      final outerY = center.dy + (innerRadius + 4) * math.sin(angle);
      final innerX = center.dx + (innerRadius - 6) * math.cos(angle);
      final innerY = center.dy + (innerRadius - 6) * math.sin(angle);

      canvas.drawLine(
        Offset(outerX, outerY),
        Offset(innerX, innerY),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OuterRingPainter oldDelegate) => true;
}

/// Draws the wheel slices with gradient fills
class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.slices});

  final List<TreasureWheelSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = 2 * math.pi / slices.length;

    for (int i = 0; i < slices.length; i++) {
      final startAngle = -math.pi / 2 + i * sliceAngle;
      final baseColor = hexToColor(slices[i].color);

      // Gradient fill for each slice
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sliceAngle,
        colors: [
          baseColor,
          Color.lerp(baseColor, Colors.white, 0.15)!,
          baseColor,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;

      // Draw slice
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, sliceAngle, false)
        ..close();

      canvas.drawPath(path, paint);

      // Draw border between slices
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Draw inner shadow for depth
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.15),
        startAngle,
        sliceAngle,
        true,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );

      // Draw icon and label
      _drawSliceContent(canvas, center, radius, startAngle, sliceAngle, slices[i]);
    }
  }

  void _drawSliceContent(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sliceAngle,
    TreasureWheelSlice slice,
  ) {
    final textAngle = startAngle + sliceAngle / 2;
    final textRadius = radius * 0.62;
    final textX = center.dx + textRadius * math.cos(textAngle);
    final textY = center.dy + textRadius * math.sin(textAngle);

    canvas.save();
    canvas.translate(textX, textY);
    canvas.rotate(textAngle + math.pi / 2);

    // Draw label only (centered in slice)
    final textPainter = TextPainter(
      text: TextSpan(
        text: slice.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.8)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: radius * 0.45);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

/// Animated pointer with bounce
class _PointerWidget extends StatelessWidget {
  const _PointerWidget({required this.isSpinning});

  final bool isSpinning;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSpinning ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value * 4),
          child: child,
        );
      },
      child: CustomPaint(
        size: const Size(36, 28),
        painter: _PointerPainter(),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(2, 0)
      ..lineTo(size.width - 2, 0)
      ..close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Main pointer
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF1744), Color(0xFFD50000)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
