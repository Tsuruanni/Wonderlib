import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Notification type enum
// ---------------------------------------------------------------------------

enum NotificationType {
  levelUp,
  leagueChange,
  streakExtended,
  streakMilestone,
  streakFreeze,
  streakBroken,
  badgeEarned,
  assignment,
  questComplete,
  allQuestsComplete,
}

// ---------------------------------------------------------------------------
// Data class holding a queued notification entry
// ---------------------------------------------------------------------------

class NotificationEntry {
  NotificationEntry({
    required this.type,
    required this.data,
    required this.overlayEntry,
    this.onDismiss,
  });

  final NotificationType type;

  /// Payload stored for introspection (e.g. checking if a type is already shown).
  final Object? data;
  final OverlayEntry overlayEntry;
  final VoidCallback? onDismiss;
}

// ---------------------------------------------------------------------------
// Singleton overlay manager
// ---------------------------------------------------------------------------

class NotificationOverlayManager {
  NotificationOverlayManager._();

  static final NotificationOverlayManager instance =
      NotificationOverlayManager._();

  final List<NotificationEntry> _active = [];
  final Set<NotificationEntry> _dismissing = {};
  OverlayEntry? _barrierEntry;

  static const int _maxVisible = 3;

  // ---- public API --------------------------------------------------------

  /// Push a new notification card onto the overlay stack.
  ///
  /// [cardBuilder] receives a `dismiss` callback that the card widget should
  /// call when the user taps "Continue" / swipes away / etc.
  void show({
    required OverlayState overlay,
    required NotificationType type,
    required Object? data,
    required Widget Function(VoidCallback dismiss) cardBuilder,
    VoidCallback? onDismiss,
  }) {

    // Show barrier before the first card
    if (_active.isEmpty) {
      _showBarrier(overlay);
    }

    late final NotificationEntry entry;

    final overlayEntry = OverlayEntry(
      builder: (_) {
        final index = _active.indexOf(entry);
        if (index == -1) return const SizedBox.shrink();

        final depth = _active.length - 1 - index;
        final isDismissing = _dismissing.contains(entry);

        return _CascadeCard(
          depth: depth,
          isDismissing: isDismissing,
          child: cardBuilder(() => dismiss(entry)),
        );
      },
    );

    entry = NotificationEntry(
      type: type,
      data: data,
      overlayEntry: overlayEntry,
      onDismiss: onDismiss,
    );

    _active.add(entry);
    overlay.insert(overlayEntry);

    // Previous entries need to recalculate their depth
    _rebuildAll();
  }

  /// Dismiss with exit animation (200ms), then remove.
  void dismiss(NotificationEntry entry) {
    if (!_active.contains(entry)) return;
    if (_dismissing.contains(entry)) return;

    _dismissing.add(entry);
    _rebuildAll();

    Future.delayed(const Duration(milliseconds: 200), () {
      _dismissing.remove(entry);
      if (!_active.contains(entry)) return;

      entry.overlayEntry.remove();
      _active.remove(entry);
      entry.onDismiss?.call();

      if (_active.isEmpty) {
        _removeBarrier();
      } else {
        _rebuildAll();
      }
    });
  }

  /// Remove the topmost (most recently added) notification.
  void dismissTop() {
    if (_active.isEmpty) return;
    dismiss(_active.last);
  }

  /// Remove all active notifications instantly (no animation).
  void dismissAll() {
    for (final entry in [..._active]) {
      entry.overlayEntry.remove();
      entry.onDismiss?.call();
    }
    _active.clear();
    _dismissing.clear();
    _removeBarrier();
  }

  // ---- barrier -----------------------------------------------------------

  void _showBarrier(OverlayState overlay) {
    _barrierEntry = OverlayEntry(
      builder: (_) => _NotificationBarrier(onTap: dismissTop),
    );
    overlay.insert(_barrierEntry!);
  }

  void _removeBarrier() {
    _barrierEntry?.remove();
    _barrierEntry = null;
  }

  // ---- helpers -----------------------------------------------------------

  void _rebuildAll() {
    _barrierEntry?.markNeedsBuild();
    for (final entry in _active) {
      entry.overlayEntry.markNeedsBuild();
    }
  }
}

// ---------------------------------------------------------------------------
// Semi-transparent backdrop behind the card stack (fades in)
// ---------------------------------------------------------------------------

class _NotificationBarrier extends StatelessWidget {
  const _NotificationBarrier({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        builder: (context, opacity, _) => GestureDetector(
          onTap: onTap,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.4 * opacity),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Depth-based cascade positioning with implicit animations
// ---------------------------------------------------------------------------

class _CascadeCard extends StatelessWidget {
  const _CascadeCard({
    required this.depth,
    required this.isDismissing,
    required this.child,
  });

  final int depth;
  final bool isDismissing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Cards beyond max visible are hidden (unless dismissing)
    if (depth >= NotificationOverlayManager._maxVisible && !isDismissing) {
      return const SizedBox.shrink();
    }

    final scale = isDismissing ? 0.8 : (1.0 - depth * 0.05);
    final translateY = isDismissing ? 0.0 : (-20.0 * depth);
    final opacity = isDismissing ? 0.0 : 1.0;
    final duration = isDismissing
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 300);
    final curve = isDismissing ? Curves.easeIn : Curves.easeOut;

    return Positioned.fill(
      child: Center(
        child: AnimatedOpacity(
          opacity: opacity,
          duration: duration,
          curve: curve,
          child: AnimatedContainer(
            duration: duration,
            curve: curve,
            // ignore: deprecated_member_use
            transform: Matrix4.identity()
              // ignore: deprecated_member_use
              ..translate(0.0, translateY)
              // ignore: deprecated_member_use
              ..scale(scale, scale),
            transformAlignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
