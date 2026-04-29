import 'package:flutter/material.dart';

/// A small inline badge that shows how many other entities reference the
/// current one (e.g. "Used by 3 templates"). Loads asynchronously and
/// renders nothing until the count resolves.
///
/// Wire it next to delete buttons or in entity headers to give the operator
/// safe context before destructive actions.
class UsageCountBadge extends StatelessWidget {
  const UsageCountBadge({
    super.key,
    required this.count,
    required this.singular,
    required this.plural,
    this.icon = Icons.link,
    this.onTap,
  });

  /// Future resolving to the number of dependents. Null is treated as 0.
  final Future<int?> count;

  /// Label for `count == 1` (e.g. `'şablon'`).
  final String singular;

  /// Label for `count != 1` (e.g. `'şablon'` — Turkish has no plural form).
  final String plural;

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: count,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 0,
            height: 0,
          );
        }
        final n = snap.data ?? 0;
        if (n == 0) return const SizedBox.shrink();
        final label = n == 1 ? singular : plural;
        final color =
            n > 0 ? Colors.orange.shade700 : Colors.grey.shade600;
        final body = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                '$n $label',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
        if (onTap == null) return body;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: body,
        );
      },
    );
  }
}
