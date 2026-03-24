import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/router.dart';
import '../../../domain/entities/streak_result.dart';
import '../../providers/user_provider.dart';
import 'badge_earned_dialog.dart';
import 'streak_event_dialog.dart';

/// Shows a celebration dialog when user levels up
/// Listens to levelUpEventProvider and displays appropriate celebration
class LevelUpCelebrationListener extends ConsumerStatefulWidget {
  const LevelUpCelebrationListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<LevelUpCelebrationListener> createState() =>
      _LevelUpCelebrationListenerState();
}

class _LevelUpCelebrationListenerState
    extends ConsumerState<LevelUpCelebrationListener> {
  final _dialogQueue = <Future<void> Function()>[];
  bool _isShowingDialog = false;

  void _enqueueDialog(Future<void> Function() showFn) {
    _dialogQueue.add(showFn);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (!mounted || _isShowingDialog || _dialogQueue.isEmpty) return;
    _isShowingDialog = true;
    final fn = _dialogQueue.removeAt(0);
    await fn();
    _isShowingDialog = false;
    if (mounted) _processQueue();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LevelUpEvent?>(levelUpEventProvider, (previous, next) {
      if (next != null) {
        _enqueueDialog(() => _showLevelUpCelebration(next));
      }
    });

    ref.listen<LeagueTierChangeEvent?>(leagueTierChangeEventProvider,
        (previous, next) {
      if (next != null) {
        _enqueueDialog(() => _showLeagueTierChange(next));
      }
    });

    ref.listen<StreakResult?>(streakEventProvider, (previous, next) {
      if (next != null && next.hasEvent) {
        _enqueueDialog(() => _showStreakEvent(next));
      }
    });

    ref.listen<BadgeEarnedEvent?>(badgeEarnedEventProvider, (previous, next) {
      if (next != null) {
        _enqueueDialog(() => _showBadgeEarned(next));
      }
    });

    return widget.child;
  }

  Future<void> _showLevelUpCelebration(LevelUpEvent event) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => _LevelUpDialog(event: event),
    );
    ref.read(levelUpEventProvider.notifier).state = null;
  }

  Future<void> _showStreakEvent(StreakResult result) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => StreakEventDialog(result: result),
    );
    ref.read(streakEventProvider.notifier).state = null;
  }

  Future<void> _showLeagueTierChange(LeagueTierChangeEvent event) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => _LeagueTierChangeDialog(event: event),
    );
    ref.read(leagueTierChangeEventProvider.notifier).state = null;
  }

  Future<void> _showBadgeEarned(BadgeEarnedEvent event) async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (context) => BadgeEarnedDialog(badges: event.badges),
    );
    ref.read(badgeEarnedEventProvider.notifier).state = null;
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
                colors: [Colors.indigo.shade700, Colors.indigo.shade900],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),

                const Text(
                  'Level Up!',
                  style: TextStyle(
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

                Text(
                  'Great job! Keep it up!',
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
}

// ============================================
// LEAGUE TIER CHANGE DIALOG
// ============================================

class _LeagueTierChangeDialog extends StatefulWidget {
  const _LeagueTierChangeDialog({required this.event});

  final LeagueTierChangeEvent event;

  @override
  State<_LeagueTierChangeDialog> createState() => _LeagueTierChangeDialogState();
}

class _LeagueTierChangeDialogState extends State<_LeagueTierChangeDialog>
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
    final isPromotion = widget.event.isPromotion;
    final newTier = widget.event.newTier;

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
                colors: isPromotion
                    ? _getLeagueTierGradient(newTier)
                    : [Colors.red.shade700, Colors.red.shade900],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isPromotion ? _getLeagueTierColor(newTier) : Colors.red)
                      .withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Text(
                  isPromotion ? _getLeagueTierEmoji(newTier) : '📉',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  isPromotion ? 'League Promoted!' : 'League Demoted',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Tier transition
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
                        widget.event.oldTier.label,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          isPromotion ? Icons.arrow_forward : Icons.arrow_downward,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        newTier.label,
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

                // Motivational message
                Text(
                  isPromotion
                      ? 'Great work this week! Keep climbing!'
                      : 'Keep practicing to climb back up!',
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

  List<Color> _getLeagueTierGradient(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => [Colors.brown.shade400, Colors.brown.shade700],
      LeagueTier.silver => [Colors.grey.shade400, Colors.grey.shade600],
      LeagueTier.gold => [Colors.amber.shade400, Colors.amber.shade700],
      LeagueTier.platinum => [Colors.blueGrey.shade300, Colors.blueGrey.shade600],
      LeagueTier.diamond => [Colors.cyan.shade300, Colors.blue.shade700],
    };
  }

  Color _getLeagueTierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => Colors.brown,
      LeagueTier.silver => Colors.grey,
      LeagueTier.gold => Colors.amber,
      LeagueTier.platinum => Colors.blueGrey,
      LeagueTier.diamond => Colors.cyan,
    };
  }

  String _getLeagueTierEmoji(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => '🥉',
      LeagueTier.silver => '🥈',
      LeagueTier.gold => '🥇',
      LeagueTier.platinum => '💎',
      LeagueTier.diamond => '👑',
    };
  }
}
