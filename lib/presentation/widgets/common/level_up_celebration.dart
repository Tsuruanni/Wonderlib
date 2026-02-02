import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/user_provider.dart';

/// Shows a celebration dialog when user levels up
/// Listens to levelUpEventProvider and displays appropriate celebration
class LevelUpCelebrationListener extends ConsumerWidget {
  const LevelUpCelebrationListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LevelUpEvent?>(levelUpEventProvider, (previous, next) {
      if (next != null) {
        _showCelebration(context, ref, next);
      }
    });

    return child;
  }

  void _showCelebration(BuildContext context, WidgetRef ref, LevelUpEvent event) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _LevelUpDialog(event: event),
    ).then((_) {
      // Clear the event after dialog is dismissed
      ref.read(levelUpEventProvider.notifier).state = null;
    });
  }
}

class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({required this.event});

  final LevelUpEvent event;

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTierUp = widget.event.isTierUp;
    final tier = widget.event.newTier;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isTierUp
                    ? _getTierGradient(tier)
                    : [Colors.indigo.shade700, Colors.indigo.shade900],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isTierUp ? _getTierColor(tier) : Colors.indigo)
                      .withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon/Emoji
                Text(
                  isTierUp ? _getTierEmoji(tier) : '🎉',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  isTierUp ? 'New Rank!' : 'Level Up!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Level display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Level ${widget.event.oldLevel}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Level ${widget.event.newLevel}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tier name (if tier up)
                if (isTierUp) ...[
                  Text(
                    tier.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Motivational message
                Text(
                  isTierUp
                      ? 'Amazing progress! Keep reading!'
                      : 'Great job! Keep it up!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Close button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getTierGradient(UserLevel tier) {
    return switch (tier) {
      UserLevel.bronze => [Colors.brown.shade400, Colors.brown.shade700],
      UserLevel.silver => [Colors.grey.shade400, Colors.grey.shade600],
      UserLevel.gold => [Colors.amber.shade400, Colors.amber.shade700],
      UserLevel.platinum => [Colors.blueGrey.shade300, Colors.blueGrey.shade600],
      UserLevel.diamond => [Colors.cyan.shade300, Colors.blue.shade700],
    };
  }

  Color _getTierColor(UserLevel tier) {
    return switch (tier) {
      UserLevel.bronze => Colors.brown,
      UserLevel.silver => Colors.grey,
      UserLevel.gold => Colors.amber,
      UserLevel.platinum => Colors.blueGrey,
      UserLevel.diamond => Colors.cyan,
    };
  }

  String _getTierEmoji(UserLevel tier) {
    return switch (tier) {
      UserLevel.bronze => '🥉',
      UserLevel.silver => '🥈',
      UserLevel.gold => '🥇',
      UserLevel.platinum => '💎',
      UserLevel.diamond => '👑',
    };
  }
}
