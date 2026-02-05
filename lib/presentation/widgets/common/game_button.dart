import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

enum GameButtonVariant {
  primary,
  secondary,
  danger,
  wasp,
  neutral,
  outline, // Special case
}

class GameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final GameButtonVariant variant;
  final bool fullWidth;
  final Widget? icon;

  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GameButtonVariant.primary,
    this.fullWidth = false,
    this.icon,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors based on variant
    Color faceColor;
    Color sideColor; // The "3D" part
    Color textColor;
    Color borderColor;

    // Disabled state override
    if (widget.onPressed == null) {
      faceColor = AppColors.neutral;
      sideColor = AppColors.neutralDark;
      textColor = AppColors.neutralText;
      borderColor = AppColors.neutral;
    } else {
      switch (widget.variant) {
        case GameButtonVariant.primary:
          faceColor = AppColors.primary;
          sideColor = AppColors.primaryDark;
          textColor = AppColors.white;
          borderColor = AppColors.primary;
          break;
        case GameButtonVariant.secondary:
          faceColor = AppColors.secondary;
          sideColor = AppColors.secondaryDark;
          textColor = AppColors.white;
          borderColor = AppColors.secondary;
          break;
        case GameButtonVariant.danger:
          faceColor = AppColors.danger;
          sideColor = AppColors.dangerDark;
          textColor = AppColors.white;
          borderColor = AppColors.danger;
          break;
        case GameButtonVariant.wasp:
          faceColor = AppColors.wasp;
          sideColor = AppColors.waspDark;
          textColor = AppColors.black; // Better readability on yellow
          borderColor = AppColors.wasp;
          break;
        case GameButtonVariant.neutral:
          faceColor = AppColors.white;
          sideColor = AppColors.neutral;
          textColor = AppColors.black;
          borderColor = AppColors.neutral;
          break;
        case GameButtonVariant.outline:
          faceColor = AppColors.white; // Or transparent? Usually white in these apps
          sideColor = AppColors.neutral;
          textColor = AppColors.primary; // Outline usually matches primary?
          borderColor = AppColors.neutral;
          break;
      }
    }
    
    // For outline variant override
    if (widget.variant == GameButtonVariant.outline && widget.onPressed != null) {
      sideColor = AppColors.neutral; // Bottom
      borderColor = AppColors.neutral; // Top/Sides
      textColor = AppColors.primary;
    }

    // Height offset for 3D effect
    // When NOT pressed: Top is high (e.g. margin bottom 4)
    // When pressed: Top is low (margin bottom 0), transforming down
    
    // But standard implementation is:
    // Container with height H + D
    // Inner container with height H
    // Positioned absolute or stacked? 
    // Let's use a simpler Stack approach:
    
    const double borderHeight = 4.0;
    final double offset = _isPressed ? borderHeight : 0.0;
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: (details) {
         _onTapUp(details);
         // Do not call onPressed here
      },
      onTap: () {
        widget.onPressed?.call();
      },
      onTapCancel: _onTapCancel,
      child: SizedBox(
        width: widget.fullWidth ? double.infinity : null,
        height: 50.0 + borderHeight, // Base height + 3D depth
        child: Stack(
          children: [
            // Bottom Layer (Shadow/3D Side)
            Positioned(
              left: 0, 
              right: 0,
              top: borderHeight, 
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: sideColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            
            // Top Layer (Face)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: offset,
              bottom: borderHeight - offset,
              child: Container(
                decoration: BoxDecoration(
                  color: faceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: widget.variant == GameButtonVariant.outline 
                    ? Border.all(color: AppColors.neutral, width: 2)
                    : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      // Force icon color if needed
                      IconTheme(
                        data: IconThemeData(
                          color: textColor,
                          size: 24,
                        ),
                        child: widget.icon!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Nunito',
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
