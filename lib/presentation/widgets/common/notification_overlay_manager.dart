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
  OverlayEntry? _barrierEntry;

  static const int _maxVisible = 3;

  // ---- public API --------------------------------------------------------

  /// Push a new notification card onto the overlay stack.
  ///
  /// [cardBuilder] receives a `dismiss` callback that the card widget should
  /// call when the user taps "Continue" / swipes away / etc.
  void show({
    required BuildContext context,
    required NotificationType type,
    required Object? data,
    required Widget Function(VoidCallback dismiss) cardBuilder,
    VoidCallback? onDismiss,
  }) {
    final overlay = Overlay.of(context);

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

        return _CascadeCard(
          depth: depth,
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

  /// Remove a specific notification entry.
  void dismiss(NotificationEntry entry) {
    if (!_active.contains(entry)) return;

    entry.overlayEntry.remove();
    _active.remove(entry);
    entry.onDismiss?.call();

    if (_active.isEmpty) {
      _removeBarrier();
    } else {
      _rebuildAll();
    }
  }

  /// Remove the topmost (most recently added) notification.
  void dismissTop() {
    if (_active.isEmpty) return;
    dismiss(_active.last);
  }

  /// Remove all active notifications.
  void dismissAll() {
    for (final entry in [..._active]) {
      entry.overlayEntry.remove();
      entry.onDismiss?.call();
    }
    _active.clear();
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
// Semi-transparent backdrop behind the card stack
// ---------------------------------------------------------------------------

class _NotificationBarrier extends StatelessWidget {
  const _NotificationBarrier({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Depth-based cascade positioning wrapper
// ---------------------------------------------------------------------------

class _CascadeCard extends StatelessWidget {
  const _CascadeCard({
    required this.depth,
    required this.child,
  });

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Cards beyond _maxVisible are hidden
    if (depth >= NotificationOverlayManager._maxVisible) {
      return const SizedBox.shrink();
    }

    final scale = 1.0 - depth * 0.05; // 1.0, 0.95, 0.90
    final translateY = -20.0 * depth; // 0, -20, -40

    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        ),
      ),
    );
  }
}
