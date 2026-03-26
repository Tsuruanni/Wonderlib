import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Duolingo-style card with 2px border, flat shadow, and rounded corners.
/// Drop-in replacement for Card in teacher screens.
class PlayfulCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius - 2),
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
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
