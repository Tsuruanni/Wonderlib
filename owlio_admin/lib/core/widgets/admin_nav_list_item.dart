import 'package:flutter/material.dart';

/// A single clickable sidebar item.
///
/// - Active state: indigo tint background + 3px left accent bar + indigo icon/text.
/// - Hover: light grey background.
/// - Inactive: transparent.
class AdminNavListItem extends StatelessWidget {
  const AdminNavListItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  static const Color _accent = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? _accent.withValues(alpha: 0.1) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isActive ? _accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? _accent : Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? _accent : Colors.grey.shade800,
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
