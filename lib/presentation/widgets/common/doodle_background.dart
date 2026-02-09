import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

class DoodleBackground extends StatelessWidget {
  const DoodleBackground({
    super.key,
    required this.child,
    this.iconColor = const Color(0xFFE5E5E5), // Very faint grey
  });

  final Widget child;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The doodle painter
        Positioned.fill(
          child: CustomPaint(
            painter: _DoodlePainter(iconColor: iconColor),
          ),
        ),
        // The foreground content
        child,
      ],
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final Color iconColor;
  final Random _random = Random(42); // Deterministic seed

  _DoodlePainter({required this.iconColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = iconColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final icons = [
      Icons.star_rounded,
      Icons.bolt_rounded,
      Icons.menu_book_rounded,
      Icons.lightbulb_rounded,
      Icons.school_rounded,
      Icons.auto_stories_rounded,
      Icons.edit_rounded,
    ];

    // Grid-based scattering to avoid overlap
    const gridSize = 100.0;
    final cols = (size.width / gridSize).ceil();
    final rows = (size.height / gridSize).ceil();

    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        // 40% chance to draw an icon in a grid cell
        if (_random.nextDouble() > 0.6) {
          final icon = icons[_random.nextInt(icons.length)];
          
          // Random offset within the cell
          final dx = (i * gridSize) + _random.nextDouble() * (gridSize - 30);
          final dy = (j * gridSize) + _random.nextDouble() * (gridSize - 30);
          
          // Random rotation
          final rotation = (_random.nextDouble() - 0.5) * 0.5; // +/- 0.25 radians

          _drawIcon(canvas, icon, Offset(dx, dy), paint, rotation);
        }
      }
    }
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset offset, Paint paint, double rotation) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 24,
          fontFamily: icon.fontFamily,
          color: Paint().color == Colors.transparent ? null : paint.color,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    canvas.save();
    canvas.translate(offset.dx + textPainter.width / 2, offset.dy + textPainter.height / 2);
    canvas.rotate(rotation);
    canvas.translate(-(offset.dx + textPainter.width / 2), -(offset.dy + textPainter.height / 2));
    
    textPainter.paint(canvas, offset);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
