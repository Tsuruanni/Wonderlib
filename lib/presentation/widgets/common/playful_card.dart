import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';

/// Duolingo-style card with 2px border, flat shadow, and rounded corners.
/// Drop-in replacement for Card in teacher screens.
///
/// When [onTap] is set, the card animates like a physical button: sinks
/// 4px down and its shadow collapses to feel "pressed." Plays a light
/// haptic tick on press to match the AnimatedGameButton feel.
class PlayfulCard extends StatefulWidget {
  const PlayfulCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(16),
    this.borderColor = AppColors.neutral,
    this.shadowColor = AppColors.neutral,
    this.color = AppColors.white,
    this.borderRadius = 16.0,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final Color shadowColor;
  final Color color;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  State<PlayfulCard> createState() => _PlayfulCardState();
}

class _PlayfulCardState extends State<PlayfulCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _pressed;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      margin: widget.margin,
      transform: Matrix4.translationValues(0, pressed ? 4 : 0, 0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: widget.borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: widget.shadowColor,
            offset: pressed ? Offset.zero : const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _setPressed(true);
      },
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _setPressed(false),
      child: card,
    );
  }
}

/// A PlayfulCard variant that groups items in a list with dividers.
/// Used for activity feeds, student lists in a single card.
class PlayfulListCard extends StatelessWidget {
  const PlayfulListCard({
    super.key,
    required this.children,
    this.margin = EdgeInsets.zero,
    this.itemPadding = const EdgeInsets.all(12),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry itemPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neutral,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Padding(padding: itemPadding, child: children[i]),
              if (i < children.length - 1)
                const Divider(height: 1, thickness: 1, color: AppColors.neutral),
            ],
          ],
        ),
      ),
    );
  }
}
