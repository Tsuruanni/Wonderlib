import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/text_styles.dart';
import '../../../../app/theme.dart';

export 'game_button.dart' show GameButtonVariant;
import 'game_button.dart' show GameButtonVariant;

/// A highly animated button with a 3D press effect.
/// Simulates "pushing down" by changing margin/translation.
class AnimatedGameButton extends StatefulWidget {
  final String? label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final GameButtonVariant variant;
  final bool fullWidth;
  final bool isSelected; // For toggle behavior
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;

  const AnimatedGameButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.variant = GameButtonVariant.primary,
    this.fullWidth = false,
    this.isSelected = false,
    this.height = 48.0,
    this.borderRadius = AppRadius.button,
    this.textStyle,
  });

  @override
  State<AnimatedGameButton> createState() => _AnimatedGameButtonState();
}

class _AnimatedGameButtonState extends State<AnimatedGameButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late double _scale;

  @override
  void initState() {
    super.initState();
    _scale = 1.0;
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isPressed = true;
      _scale = 0.98;
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() {
      _isPressed = false;
      _scale = 1.0;
    });
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() {
      _isPressed = false;
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Color Logic
    Color faceColor;
    Color sideColor;
    Color textColor;
    Color borderColor;

    if (widget.onPressed == null &&
        widget.variant != GameButtonVariant.success &&
        widget.variant != GameButtonVariant.danger) {
      faceColor = Colors.grey[300]!;
      sideColor = Colors.grey[400]!;
      textColor = Colors.grey[500]!;
      borderColor = Colors.transparent;
    } else {
      switch (widget.variant) {
        case GameButtonVariant.primary:
          faceColor = AppColors.primary;
          sideColor = AppColors.primaryDark;
          textColor = Colors.white;
          borderColor = AppColors.primary;
          break;
        case GameButtonVariant.secondary:
          faceColor = const Color(0xFF3B82F6); // Blue 500
          sideColor = const Color(0xFF1D4ED8); // Blue 700
          textColor = Colors.white;
          borderColor = const Color(0xFF3B82F6);
          break;
        case GameButtonVariant.success:
          faceColor = const Color(0xFF58CC02); // Duolingo Green
          sideColor = const Color(0xFF46A302);
          textColor = Colors.white;
          borderColor = const Color(0xFF58CC02);
          break;
        case GameButtonVariant.danger:
          faceColor = const Color(0xFFFF4B4B); // Duolingo Red
          sideColor = const Color(0xFFEA2B2B);
          textColor = Colors.white;
          borderColor = const Color(0xFFFF4B4B);
          break;
        case GameButtonVariant.wasp:
          faceColor = AppColors.wasp;
          sideColor = AppColors.waspDark;
          textColor = Colors.black;
          borderColor = AppColors.wasp;
          break;
        case GameButtonVariant.neutral:
          faceColor = Colors.white;
          sideColor = const Color(0xFFE5E7EB);
          textColor = const Color(0xFF4B5563);
          borderColor = const Color(0xFFE5E7EB);
          break;
        case GameButtonVariant.outline:
          faceColor = Colors.transparent;
          sideColor = Colors.transparent;
          textColor = AppColors.primary;
          borderColor = AppColors.primary;
          break;
        case GameButtonVariant.ghost:
          faceColor = Colors.transparent;
          sideColor = Colors.transparent;
          textColor = AppColors.primary;
          borderColor = Colors.transparent;
          break;
      }
    }

    final bool isFlat = widget.variant == GameButtonVariant.outline ||
        widget.variant == GameButtonVariant.ghost;
    final double depth = isFlat ? 0 : 3.0;
    final double currentDepth = _isPressed ? 0.0 : depth;
    final double marginTop = _isPressed ? depth : 0.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height + depth, // Total allocated height including depth
          child: Stack(
            children: [
              // 3D Side (Bottom)
              if (!isFlat)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: depth, // Start where the face would start when pressed
                  child: Container(
                    decoration: BoxDecoration(
                      color: sideColor,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  ),
                ),
              
              // Face (Top)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                top: marginTop,
                bottom: currentDepth, // Moves down when pressed
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: faceColor,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: widget.variant == GameButtonVariant.ghost
                          ? Colors.transparent
                          : (widget.variant == GameButtonVariant.neutral
                              ? const Color(0xFFE5E7EB)
                              : (widget.variant == GameButtonVariant.outline
                                  ? borderColor
                                  : faceColor)),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          IconTheme(
                            data: IconThemeData(
                              color: textColor,
                              size: 24,
                            ),
                            child: widget.icon!,
                          ),
                          if (widget.label != null) const SizedBox(width: 8),
                        ],
                        if (widget.label != null)
                          Flexible(
                            child: Text(
                              widget.label!.toUpperCase(),
                              style: widget.textStyle ??
                                  AppTextStyles.button(color: textColor).copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
