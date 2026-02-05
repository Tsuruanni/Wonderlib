import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

class ProProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;

  const ProProgressBar({
    super.key,
    required this.progress,
    this.height = 16.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;
    final effectiveBgColor = backgroundColor ?? AppColors.neutral;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Stack(
        children: [
          // Progress Fill
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: effectiveColor,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
          
          // Shine (Top Highlight) - Optional Polish
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            heightFactor: 0.3, // Top 30% only
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: height / 4), // inset slightly
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
