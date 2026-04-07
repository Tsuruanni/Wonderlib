import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/treasure_wheel.dart';

/// Parses a hex color string like '#FF9800' to a Color
Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

/// The spinning wheel widget with pointer
class TreasureWheelWidget extends StatefulWidget {
  const TreasureWheelWidget({
    super.key,
    required this.slices,
    this.targetSliceIndex,
    this.onSpinComplete,
  });

  final List<TreasureWheelSlice> slices;
  final int? targetSliceIndex;
  final VoidCallback? onSpinComplete;

  @override
  State<TreasureWheelWidget> createState() => TreasureWheelWidgetState();
}

class TreasureWheelWidgetState extends State<TreasureWheelWidget>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _spinController;
  double _currentAngle = 0;
  bool _isIdleSpinning = false;

  @override
  void initState() {
    super.initState();
    // Idle spin: continuous fast rotation while waiting for RPC
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _idleController.addListener(() {
      if (_isIdleSpinning) {
        setState(() {
          _currentAngle += 0.15; // ~9 degrees per frame tick
        });
      }
    });

    // Final spin: decelerate to target
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  /// Start continuous fast rotation (called when Spin button is pressed)
  void startIdleSpin() {
    _isIdleSpinning = true;
    _idleController.repeat();
  }

  /// Stop idle spin and decelerate to land on the target slice
  void spinTo(int targetIndex) {
    // Stop idle rotation
    _isIdleSpinning = false;
    _idleController.stop();

    final sliceCount = widget.slices.length;
    final sliceAngle = 2 * math.pi / sliceCount;

    // The pointer is at the top (12 o'clock = -pi/2).
    // Target angle: negative rotation to bring target slice under pointer.
    final random = math.Random();
    final offsetInSlice = (random.nextDouble() * 0.6 + 0.2) * sliceAngle; // 20-80% of slice
    final targetAngle = -(targetIndex * sliceAngle + offsetInSlice);

    // Add 4 full rotations for dramatic deceleration from current position
    final totalRotation = targetAngle - _currentAngle + (4 * 2 * math.pi);

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
      widget.onSpinComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pointer triangle at top
        CustomPaint(
          size: const Size(30, 20),
          painter: _PointerPainter(),
        ),
        const SizedBox(height: 4),
        // Wheel
        SizedBox(
          width: 300,
          height: 300,
          child: Transform.rotate(
            angle: _currentAngle,
            child: CustomPaint(
              size: const Size(300, 300),
              painter: _WheelPainter(slices: widget.slices),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the wheel slices
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
      final paint = Paint()
        ..color = _hexToColor(slices[i].color)
        ..style = PaintingStyle.fill;

      // Draw slice arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );

      // Draw border
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Draw label text
      final textAngle = startAngle + sliceAngle / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + math.pi / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: slices[i].label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: radius * 0.5);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // Draw center circle
    canvas.drawCircle(
      center,
      20,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

/// Draws the pointer triangle above the wheel
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = Colors.red,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.red.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
