import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme.dart';

enum ActivityCardVariant {
  neutral,
  correct,
  wrong,
}

/// A container widget with a "3D" style hard bottom shadow/border.
/// Used for wrapping activity content.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.child,
    this.variant = ActivityCardVariant.neutral,
    this.padding,
    this.margin,
  });

  final Widget child;
  final ActivityCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color backgroundColor;

    // TODO: Move these specific colors to AppTheme or use existing ones if they match
    switch (variant) {
      case ActivityCardVariant.neutral:
        borderColor = AppColors.gray200;
        backgroundColor = Colors.white;
      case ActivityCardVariant.correct:
        borderColor = const Color(0xFF38A169); // Green 600
        backgroundColor = const Color(0xFFF0FFF4); // Green 50
      case ActivityCardVariant.wrong:
        borderColor = const Color(0xFFE53E3E); // Red 600
        backgroundColor = const Color(0xFFFFF5F5); // Red 50
    }

    // Check for dark mode via theme if needed, but for now enforcing these specific "gamified" colors
    // as they are usually bright/specific. If the app needs strict dark mode, we can adjust.
    // Assuming context-based theme check would go here.

    final card = Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // Slightly less than container
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    // Add Shake animation on Wrong state
    if (variant == ActivityCardVariant.wrong) {
      return card.animate(onPlay: (controller) => controller.forward()).shake(
            duration: 500.ms,
            hz: 4,
            rotation: 0.05, // Slight rotation for a "cartoonish" shake
          );
    }

    // Add Pulse/Jump animation on Correct state
    if (variant == ActivityCardVariant.correct) {
      return card
          .animate(onPlay: (controller) => controller.forward())
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.02, 1.02),
            duration: 200.ms,
            curve: Curves.easeOutBack,
          )
          .then()
          .scale(
            begin: const Offset(1.02, 1.02),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
            curve: Curves.easeOut,
          );
    }

    return card;
  }
}
