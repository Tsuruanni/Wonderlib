import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Animated START bubble shown above the active node.
class StartBubble extends StatefulWidget {
  const StartBubble({super.key, this.scale = 1.0});

  final double scale;

  @override
  State<StartBubble> createState() => _StartBubbleState();
}

class _StartBubbleState extends State<StartBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _bounce = Tween(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounce.value * s),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 8 * s),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14 * s),
              border: Border.all(color: AppColors.neutral, width: 2 * s),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neutral.withValues(alpha: 0.5),
                  offset: Offset(0, 3 * s),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              'START',
              style: GoogleFonts.nunito(
                fontSize: 14 * s,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 1 * s,
              ),
            ),
          ),
          // Triangle pointer
          CustomPaint(
            size: Size(16 * s, 8 * s),
            painter: _TrianglePainter(color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
