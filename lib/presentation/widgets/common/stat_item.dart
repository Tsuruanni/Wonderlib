import 'package:flutter/material.dart';

import '../../../core/utils/extensions/context_extensions.dart';

/// Reusable stat item widget for displaying a value with label
class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.valueStyle,
    this.labelStyle,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: color ?? context.colorScheme.onPrimaryContainer,
            size: 24,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          value,
          style: valueStyle ??
              context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: labelStyle ??
              context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
        ),
      ],
    );
  }
}
