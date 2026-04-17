import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

/// Canonical progress bar matching the badges-page design language.
/// Fully rounded, gray200 background, fill with a 3px bottom-border shadow
/// for a tactile "button" depth feel.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.progress,
    this.fillColor,
    this.fillShadow,
    this.backgroundColor,
    this.height = 12.0,
    this.duration = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.overlayText,
    this.overlayTextStyle,
  });

  final double progress;
  final Color? fillColor;
  final Color? fillShadow;
  final Color? backgroundColor;
  final double height;
  final Duration duration;
  final Curve curve;

  /// Optional centered text overlay (e.g. "5 / 10"). When set, the bar renders
  /// text on top of the fill. Use [overlayTextStyle] to customize.
  final String? overlayText;
  final TextStyle? overlayTextStyle;

  @override
  Widget build(BuildContext context) {
    final effectiveFill = fillColor ?? AppColors.primary;
    final effectiveShadow = fillShadow ?? AppColors.primaryDark;
    final effectiveBg = backgroundColor ?? AppColors.gray200;
    final clamped = progress.clamp(0.0, 1.0);

    final fillWidget = Container(
      decoration: BoxDecoration(
        color: effectiveFill,
        borderRadius: BorderRadius.circular(999),
        border: Border(
          bottom: BorderSide(color: effectiveShadow, width: 3),
        ),
      ),
    );

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: duration == Duration.zero
              ? FractionallySizedBox(widthFactor: clamped, child: fillWidget)
              : AnimatedFractionallySizedBox(
                  duration: duration,
                  curve: curve,
                  widthFactor: clamped,
                  child: fillWidget,
                ),
        ),
      ),
    );

    if (overlayText == null) return bar;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: bar),
          Positioned.fill(
            child: Center(
              child: Text(
                overlayText!,
                style: overlayTextStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
