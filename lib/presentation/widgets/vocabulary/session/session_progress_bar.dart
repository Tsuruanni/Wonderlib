import 'package:flutter/material.dart';

/// Top progress bar for vocabulary session
class SessionProgressBar extends StatelessWidget {
  const SessionProgressBar({
    super.key,
    required this.progress,
    required this.xpEarned,
    this.comboActive = false,
  });

  /// Progress from 0.0 to 1.0
  final double progress;
  final int xpEarned;
  final bool comboActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 16,
      child: Stack(
        children: [
          // Background track
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          
          // Animated Fill
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: comboActive
                      ? [Colors.orange, Colors.deepOrange]
                      : [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (comboActive ? Colors.orange : theme.colorScheme.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // Optional: Add a "shine" or pattern overlay here
            ),
          ),
          
          // Optional: Segments or highlights could go here
        ],
      ),
    );
  }

  // _showExitDialog removed as it is now handled by the parent screen
}
