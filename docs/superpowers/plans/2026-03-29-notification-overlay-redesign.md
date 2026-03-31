# Notification Overlay Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the sequential `showDialog()` notification queue with a stacked Overlay system where all active notifications are visible simultaneously as cascading white cards, individually dismissible.

**Architecture:** A `NotificationOverlayManager` manages OverlayEntry instances and cascade positioning. A unified `NotificationCard` widget renders all 8 notification types in a consistent Duolingo-style white card. `AppNotificationListener` is updated to call the overlay manager instead of `showDialog()`.

**Tech Stack:** Flutter Overlay API, AnimationController, Riverpod StateProvider (existing event providers unchanged)

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/presentation/widgets/common/notification_overlay_manager.dart` | Create | OverlayEntry lifecycle, barrier, cascade positioning, dismiss logic |
| `lib/presentation/widgets/common/notification_card.dart` | Create | Unified white card widget for all 8 notification types |
| `lib/presentation/widgets/common/notification_listener.dart` | Modify | Remove `showDialog()` / FIFO queue, call overlay manager instead |
| `lib/presentation/widgets/common/streak_event_dialog.dart` | Delete | UI moved into notification_card.dart |
| `lib/presentation/widgets/common/badge_earned_dialog.dart` | Delete | UI moved into notification_card.dart |
| `lib/presentation/widgets/common/assignment_notification_dialog.dart` | Delete | UI moved into notification_card.dart |

---

### Task 1: Create NotificationOverlayManager

**Files:**
- Create: `lib/presentation/widgets/common/notification_overlay_manager.dart`

- [ ] **Step 1: Create the NotificationEntry data class and NotificationType enum**

```dart
// lib/presentation/widgets/common/notification_overlay_manager.dart

import 'package:flutter/material.dart';

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

class NotificationEntry {
  NotificationEntry({
    required this.type,
    required this.data,
    required this.onDismiss,
  });

  final NotificationType type;
  final dynamic data;
  final VoidCallback onDismiss;
  OverlayEntry? overlayEntry;
}
```

- [ ] **Step 2: Create the NotificationOverlayManager class with show/dismiss methods**

Add to the same file:

```dart
class NotificationOverlayManager {
  NotificationOverlayManager._();
  static final instance = NotificationOverlayManager._();

  final _active = <NotificationEntry>[];
  OverlayEntry? _barrierEntry;
  static const _maxVisible = 3;

  /// Currently active notification count.
  int get count => _active.length;

  /// Show a new notification. [cardBuilder] returns the card widget given
  /// a dismiss callback.
  void show({
    required BuildContext context,
    required NotificationType type,
    required dynamic data,
    required Widget Function(VoidCallback dismiss) cardBuilder,
    VoidCallback? onDismiss,
  }) {
    final overlay = Overlay.of(context);

    final entry = NotificationEntry(
      type: type,
      data: data,
      onDismiss: onDismiss ?? () {},
    );

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (_) {
        final index = _active.indexOf(entry);
        if (index < 0) return const SizedBox.shrink();
        return _NotificationPositioned(
          index: index,
          maxVisible: _maxVisible,
          child: cardBuilder(() => dismiss(entry)),
        );
      },
    );
    entry.overlayEntry = overlayEntry;

    _active.add(entry);

    // Add barrier if this is the first notification
    if (_active.length == 1) {
      _showBarrier(overlay);
    }

    overlay.insert(overlayEntry);
    _rebuildAll();
  }

  /// Dismiss a specific notification entry.
  void dismiss(NotificationEntry entry) {
    if (!_active.contains(entry)) return;
    entry.overlayEntry?.remove();
    _active.remove(entry);
    entry.onDismiss();

    if (_active.isEmpty) {
      _removeBarrier();
    } else {
      _rebuildAll();
    }
  }

  /// Dismiss the topmost (last added) notification.
  void dismissTop() {
    if (_active.isEmpty) return;
    dismiss(_active.last);
  }

  /// Dismiss all notifications (e.g., on logout or navigation).
  void dismissAll() {
    for (final entry in [..._active]) {
      entry.overlayEntry?.remove();
      entry.onDismiss();
    }
    _active.clear();
    _removeBarrier();
  }

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

  void _rebuildAll() {
    _barrierEntry?.markNeedsBuild();
    for (final entry in _active) {
      entry.overlayEntry?.markNeedsBuild();
    }
  }
}
```

- [ ] **Step 3: Create the barrier widget**

Add to the same file:

```dart
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
```

- [ ] **Step 4: Create the cascade positioning widget**

Add to the same file:

```dart
class _NotificationPositioned extends StatelessWidget {
  const _NotificationPositioned({
    required this.index,
    required this.maxVisible,
    required this.child,
  });

  final int index;
  final int maxVisible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // index 0 = oldest (back), last = newest (front)
    // We want newest on top, so reverse the visual offset
    final total = maxVisible;
    // The "depth" is how far back from the front this card is
    // _active.last is front (depth 0), _active[last-1] is depth 1, etc.
    // But index is position in list. The overlay manager adds newest last.
    // Overlay entries stack: later inserts are on top. So _active.last is visually on top.
    // We need to calculate depth from the top:
    // If there are N items, item at index i has depth = (N - 1 - i)
    // But we get index from the builder. We don't know N here directly.
    // Instead, let's pass depth directly.

    // Actually, let's rethink. The OverlayEntry builder gets called with
    // the current index in _active. The last item in _active is on top.
    // depth = how many cards are above this one = (total_visible - 1 - visual_position)
    // But we want: top card (newest, last in list) = depth 0 = full size
    // card behind it = depth 1 = slightly smaller, shifted up
    // etc.

    // Since Overlay inserts newer entries on top, and _active.last is newest:
    // For the card at _active[index], its depth from top = (_active.length - 1 - index)
    // But we only get `index` here. We need the list length.
    // Let's just pass depth from the manager instead.

    // Simplified: pass depth directly. See updated manager code.
    return const SizedBox.shrink(); // placeholder — replaced in step 5
  }
}
```

- [ ] **Step 5: Refactor to use depth-based positioning with animations**

Replace `_NotificationPositioned` and update the manager to pass depth:

In `NotificationOverlayManager.show()`, change the OverlayEntry builder:

```dart
    overlayEntry = OverlayEntry(
      builder: (_) {
        final index = _active.indexOf(entry);
        if (index < 0) return const SizedBox.shrink();
        final depth = _active.length - 1 - index;
        if (depth >= _maxVisible) return const SizedBox.shrink();
        return _CascadeCard(
          depth: depth,
          child: cardBuilder(() => dismiss(entry)),
        );
      },
    );
```

Replace `_NotificationPositioned` with `_CascadeCard`:

```dart
class _CascadeCard extends StatelessWidget {
  const _CascadeCard({
    required this.depth,
    required this.child,
  });

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 - (depth * 0.05);
    final translateY = -(depth * 20.0);

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
```

Remove the `_NotificationPositioned` class entirely.

- [ ] **Step 6: Verify file compiles**

Run: `dart analyze lib/presentation/widgets/common/notification_overlay_manager.dart`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/widgets/common/notification_overlay_manager.dart
git commit -m "feat: add NotificationOverlayManager with cascade stacking"
```

---

### Task 2: Create Unified NotificationCard

**Files:**
- Create: `lib/presentation/widgets/common/notification_card.dart`

This card handles all 8 notification types with a shared visual template.

- [ ] **Step 1: Create the base card shell**

```dart
// lib/presentation/widgets/common/notification_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

class NotificationCard extends StatefulWidget {
  const NotificationCard({
    super.key,
    required this.icon,
    this.iconData,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.body,
    this.buttonLabel = 'OK',
    this.buttonColor = AppColors.primary,
    this.secondaryButtonLabel,
    this.onButtonPressed,
    this.onSecondaryButtonPressed,
    required this.onDismiss,
  });

  /// Emoji string (e.g. '🎉'). Used when [iconData] is null.
  final String icon;

  /// Material icon. When provided, renders Icon widget instead of emoji.
  final IconData? iconData;

  /// Color for the Material icon. Ignored when using emoji.
  final Color? iconColor;

  final String title;
  final String? subtitle;
  final Color? subtitleColor;

  /// Optional body widget (e.g., level transition pill, badge list).
  final Widget? body;

  final String buttonLabel;
  final Color buttonColor;

  /// If non-null, shows a secondary outlined button to the left.
  final String? secondaryButtonLabel;

  /// Called when primary button is pressed. Defaults to [onDismiss].
  final VoidCallback? onButtonPressed;

  /// Called when secondary button is pressed. Defaults to [onDismiss].
  final VoidCallback? onSecondaryButtonPressed;

  final VoidCallback onDismiss;

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.gray400,
                  ),
                ),
              ),

              // Icon
              if (widget.iconData != null)
                Icon(widget.iconData, color: widget.iconColor, size: 64)
              else
                Text(widget.icon, style: const TextStyle(fontSize: 64)),

              const SizedBox(height: 16),

              // Title
              Text(
                widget.title,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
              ),

              // Subtitle
              if (widget.subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.subtitleColor ?? AppColors.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Body (optional — pills, badge lists, etc.)
              if (widget.body != null) ...[
                const SizedBox(height: 16),
                widget.body!,
              ],

              const SizedBox(height: 24),

              // Buttons
              if (widget.secondaryButtonLabel != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            widget.onSecondaryButtonPressed ?? widget.onDismiss,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gray600,
                          side: const BorderSide(color: AppColors.gray300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.secondaryButtonLabel!,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            widget.onButtonPressed ?? widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.buttonLabel,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onButtonPressed ?? widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.buttonLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
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
```

- [ ] **Step 2: Add the transition pill helper widget**

Add below `NotificationCard`:

```dart
/// Pill showing a transition (e.g., Level 5 → Level 6, Bronze → Silver).
class _TransitionPill extends StatelessWidget {
  const _TransitionPill({
    required this.from,
    required this.to,
    required this.color,
    this.isUpward = true,
  });

  final String from;
  final String to;
  final Color color;
  final bool isUpward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            from,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.gray500,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              isUpward ? Icons.arrow_forward : Icons.arrow_downward,
              color: color,
              size: 20,
            ),
          ),
          Text(
            to,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Add factory constructors for each notification type**

Add these static methods to `NotificationCard`:

```dart
  // ── Factory builders ──────────────────────────────────────────

  static Widget levelUp({
    required int oldLevel,
    required int newLevel,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: '🎉',
      title: 'Level Up!',
      subtitle: 'Great job! Keep it up!',
      subtitleColor: AppColors.primary,
      body: _TransitionPill(
        from: 'Level $oldLevel',
        to: 'Level $newLevel',
        color: AppColors.primary,
      ),
      buttonColor: AppColors.primary,
      onDismiss: onDismiss,
    );
  }

  static Widget leagueChange({
    required String oldTierLabel,
    required String newTierLabel,
    required bool isPromotion,
    required String tierEmoji,
    required Color tierColor,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: isPromotion ? tierEmoji : '📉',
      title: isPromotion ? 'League Promoted!' : 'League Demoted',
      subtitle: isPromotion
          ? 'Great work this week! Keep climbing!'
          : 'Keep practicing to climb back up!',
      subtitleColor: isPromotion ? tierColor : AppColors.danger,
      body: _TransitionPill(
        from: oldTierLabel,
        to: newTierLabel,
        color: isPromotion ? tierColor : AppColors.danger,
        isUpward: isPromotion,
      ),
      buttonColor: isPromotion ? tierColor : AppColors.danger,
      onDismiss: onDismiss,
    );
  }

  static Widget streakExtended({
    required int newStreak,
    required int previousStreak,
    required VoidCallback onDismiss,
  }) {
    final isFirstDay = previousStreak == 0;
    const subtitles = [
      'Keep it up!',
      "You're on fire!",
      'Great habit!',
      'Consistency is key!',
      'Unstoppable!',
      'Nice streak!',
    ];

    return NotificationCard(
      icon: '',
      iconData: Icons.local_fire_department_rounded,
      iconColor: AppColors.streakOrange,
      title: isFirstDay ? "Day 1! Let's go!" : 'Day $newStreak!',
      subtitle: isFirstDay
          ? 'Your learning streak starts today!'
          : subtitles[newStreak % subtitles.length],
      subtitleColor: AppColors.streakOrange,
      buttonColor: AppColors.streakOrange,
      onDismiss: onDismiss,
    );
  }

  static Widget streakMilestone({
    required int newStreak,
    required int bonusXp,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: '',
      iconData: Icons.local_fire_department_rounded,
      iconColor: AppColors.streakOrange,
      title: '$newStreak-Day Streak!',
      subtitle: '+$bonusXp XP earned!',
      subtitleColor: AppColors.streakOrange,
      buttonColor: AppColors.streakOrange,
      onDismiss: onDismiss,
    );
  }

  static Widget streakFreeze({
    required int newStreak,
    required int freezesRemaining,
    required VoidCallback onDismiss,
  }) {
    return NotificationCard(
      icon: '',
      iconData: Icons.ac_unit,
      iconColor: AppColors.secondary,
      title: 'Streak Freeze Saved You!',
      subtitle:
          'Your $newStreak-day streak is safe.\n$freezesRemaining freeze${freezesRemaining == 1 ? '' : 's'} left.',
      subtitleColor: AppColors.secondary,
      buttonColor: AppColors.secondary,
      onDismiss: onDismiss,
    );
  }

  static Widget streakBroken({
    required int previousStreak,
    required int freezesConsumed,
    required VoidCallback onDismiss,
  }) {
    String title;
    String subtitle;

    if (previousStreak <= 6) {
      title = 'Welcome Back!';
      subtitle = 'Start a new streak today.';
    } else if (previousStreak <= 9) {
      title = 'Your $previousStreak-day streak ended';
      subtitle = 'You can build it again!';
    } else if (previousStreak <= 20) {
      title = 'Your $previousStreak-day streak was broken';
      subtitle = "Don't give up!";
    } else {
      title = 'Your $previousStreak-day streak was broken';
      subtitle = 'That was impressive — you can do it again!';
    }

    if (freezesConsumed > 0) {
      subtitle +=
          '\n\nYour $freezesConsumed freeze${freezesConsumed == 1 ? '' : 's'} covered $freezesConsumed day${freezesConsumed == 1 ? '' : 's'}, but you were away too long.';
    }

    return NotificationCard(
      icon: '',
      iconData: Icons.local_fire_department_rounded,
      iconColor: AppColors.gray400,
      title: title,
      subtitle: subtitle,
      subtitleColor: AppColors.gray500,
      buttonColor: AppColors.gray400,
      onDismiss: onDismiss,
    );
  }

  static Widget badgeEarned({
    required List<BadgeEarnedData> badges,
    required VoidCallback onDismiss,
  }) {
    final isSingle = badges.length == 1;

    return NotificationCard(
      icon: isSingle ? badges.first.icon : '🏅',
      title: isSingle ? 'New Badge!' : '${badges.length} New Badges!',
      subtitle: isSingle ? badges.first.name : null,
      subtitleColor: AppColors.gray600,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSingle && badges.first.xpReward > 0)
            _XpChip(xp: badges.first.xpReward)
          else if (!isSingle)
            ...badges.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(b.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          b.name,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                      if (b.xpReward > 0) _XpChip(xp: b.xpReward),
                    ],
                  ),
                )),
        ],
      ),
      buttonColor: AppColors.wasp,
      onDismiss: onDismiss,
    );
  }

  static Widget assignment({
    required int count,
    required VoidCallback onDismiss,
    required VoidCallback onView,
  }) {
    final isSingle = count == 1;
    return NotificationCard(
      icon: '📋',
      title: isSingle ? 'New Assignment!' : '$count Assignments Waiting!',
      subtitle: isSingle
          ? 'You have an assignment from your teacher.'
          : 'You have $count assignments from your teacher.',
      subtitleColor: AppColors.gray500,
      buttonLabel: 'View',
      buttonColor: AppColors.secondary,
      secondaryButtonLabel: 'Later',
      onButtonPressed: onView,
      onDismiss: onDismiss,
    );
  }
```

- [ ] **Step 4: Add the BadgeEarnedData helper class and XP chip**

Add at the bottom of the file:

```dart
/// Lightweight data class to avoid importing domain entity.
class BadgeEarnedData {
  const BadgeEarnedData({
    required this.icon,
    required this.name,
    required this.xpReward,
  });

  final String icon;
  final String name;
  final int xpReward;
}

class _XpChip extends StatelessWidget {
  const _XpChip({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$xp XP',
        style: GoogleFonts.nunito(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify file compiles**

Run: `dart analyze lib/presentation/widgets/common/notification_card.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/common/notification_card.dart
git commit -m "feat: add unified NotificationCard with all 8 notification types"
```

---

### Task 3: Rewrite AppNotificationListener to Use Overlay Manager

**Files:**
- Modify: `lib/presentation/widgets/common/notification_listener.dart`

- [ ] **Step 1: Replace the entire notification_listener.dart file**

The file currently contains `AppNotificationListener` (with FIFO queue, `showDialog` calls), `_LevelUpDialog`, and `_LeagueTierChangeDialog`. Replace it entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../app/router.dart';
import '../../../domain/entities/streak_result.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../../domain/entities/system_settings.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/user_provider.dart';
import 'notification_card.dart';
import 'notification_overlay_manager.dart';

/// Listens to all notification event providers and shows stacked overlay
/// notifications. Wraps the app root in app.dart.
class AppNotificationListener extends ConsumerStatefulWidget {
  const AppNotificationListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AppNotificationListener> createState() =>
      _AppNotificationListenerState();
}

class _AppNotificationListenerState
    extends ConsumerState<AppNotificationListener> {
  bool _hasShownAssignmentNotif = false;
  final _manager = NotificationOverlayManager.instance;

  @override
  Widget build(BuildContext context) {
    ref.listen<LevelUpEvent?>(levelUpEventProvider, (previous, next) {
      if (next != null) _showLevelUp(next);
    });

    ref.listen<LeagueTierChangeEvent?>(leagueTierChangeEventProvider,
        (previous, next) {
      if (next != null) _showLeagueChange(next);
    });

    ref.listen<StreakResult?>(streakEventProvider, (previous, next) {
      if (next != null) _showStreakEvent(next);
    });

    ref.listen<BadgeEarnedEvent?>(badgeEarnedEventProvider, (previous, next) {
      if (next != null) _showBadgeEarned(next);
    });

    ref.listen<AssignmentNotificationEvent?>(
        assignmentNotificationEventProvider, (previous, next) {
      if (next != null) _showAssignment(next);
    });

    // Fire assignment notification AFTER user is fully loaded (students only).
    {
      final isTeacher = ref.watch(isTeacherProvider);
      if (!isTeacher) {
        ref.listen<AsyncValue<User?>>(userControllerProvider, (previous, next) {
          if (next is AsyncData<User?> && next.value == null) {
            _hasShownAssignmentNotif = false;
            _manager.dismissAll();
            ref.read(assignmentNotificationEventProvider.notifier).state = null;
            return;
          }
          if (_hasShownAssignmentNotif) return;
          if (next is AsyncData<User?> && next.value != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted || _hasShownAssignmentNotif) return;
              _checkAndFireAssignmentNotification();
            });
          }
        });
      }
    }

    return widget.child;
  }

  BuildContext? get _overlayContext => rootNavigatorKey.currentContext;

  void _showLevelUp(LevelUpEvent event) {
    final ctx = _overlayContext;
    if (ctx == null) return;
    _manager.show(
      context: ctx,
      type: NotificationType.levelUp,
      data: event,
      cardBuilder: (dismiss) => NotificationCard.levelUp(
        oldLevel: event.oldLevel,
        newLevel: event.newLevel,
        onDismiss: dismiss,
      ),
      onDismiss: () {
        ref.read(levelUpEventProvider.notifier).state = null;
      },
    );
  }

  void _showLeagueChange(LeagueTierChangeEvent event) {
    final ctx = _overlayContext;
    if (ctx == null) return;
    _manager.show(
      context: ctx,
      type: NotificationType.leagueChange,
      data: event,
      cardBuilder: (dismiss) => NotificationCard.leagueChange(
        oldTierLabel: event.oldTier.label,
        newTierLabel: event.newTier.label,
        isPromotion: event.isPromotion,
        tierEmoji: _leagueTierEmoji(event.newTier),
        tierColor: _leagueTierColor(event.newTier),
        onDismiss: dismiss,
      ),
      onDismiss: () {
        ref.read(leagueTierChangeEventProvider.notifier).state = null;
      },
    );
  }

  void _showStreakEvent(StreakResult result) {
    final ctx = _overlayContext;
    if (ctx == null) return;

    late Widget card;
    late NotificationType type;

    // Priority: milestone > freeze-saved > streak-broken > streak-extended
    if (result.milestoneBonusXp > 0) {
      type = NotificationType.streakMilestone;
    } else if (result.freezeUsed && !result.streakBroken) {
      type = NotificationType.streakFreeze;
    } else if (result.streakBroken) {
      type = NotificationType.streakBroken;
    } else if (result.streakExtended) {
      type = NotificationType.streakExtended;
    } else {
      return;
    }

    _manager.show(
      context: ctx,
      type: type,
      data: result,
      cardBuilder: (dismiss) {
        return switch (type) {
          NotificationType.streakMilestone => NotificationCard.streakMilestone(
              newStreak: result.newStreak,
              bonusXp: result.milestoneBonusXp,
              onDismiss: dismiss,
            ),
          NotificationType.streakFreeze => NotificationCard.streakFreeze(
              newStreak: result.newStreak,
              freezesRemaining: result.freezesRemaining,
              onDismiss: dismiss,
            ),
          NotificationType.streakBroken => NotificationCard.streakBroken(
              previousStreak: result.previousStreak,
              freezesConsumed: result.freezesConsumed,
              onDismiss: dismiss,
            ),
          NotificationType.streakExtended => NotificationCard.streakExtended(
              newStreak: result.newStreak,
              previousStreak: result.previousStreak,
              onDismiss: dismiss,
            ),
          _ => const SizedBox.shrink(),
        };
      },
      onDismiss: () {
        ref.read(streakEventProvider.notifier).state = null;
      },
    );
  }

  void _showBadgeEarned(BadgeEarnedEvent event) {
    final ctx = _overlayContext;
    if (ctx == null) return;
    _manager.show(
      context: ctx,
      type: NotificationType.badgeEarned,
      data: event,
      cardBuilder: (dismiss) => NotificationCard.badgeEarned(
        badges: event.badges
            .map((b) => BadgeEarnedData(
                  icon: b.badgeIcon,
                  name: b.badgeName,
                  xpReward: b.xpReward,
                ))
            .toList(),
        onDismiss: dismiss,
      ),
      onDismiss: () {
        ref.read(badgeEarnedEventProvider.notifier).state = null;
      },
    );
  }

  void _showAssignment(AssignmentNotificationEvent event) {
    final ctx = _overlayContext;
    if (ctx == null) return;
    _manager.show(
      context: ctx,
      type: NotificationType.assignment,
      data: event,
      cardBuilder: (dismiss) => NotificationCard.assignment(
        count: event.count,
        onDismiss: dismiss,
        onView: () {
          _manager.dismissAll();
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null) {
            final path = event.assignmentId != null
                ? AppRoutes.studentAssignmentDetailPath(event.assignmentId!)
                : AppRoutes.studentAssignments;
            GoRouter.of(navContext).go(path);
          }
        },
      ),
      onDismiss: () {
        ref.read(assignmentNotificationEventProvider.notifier).state = null;
      },
    );
  }

  Future<void> _checkAndFireAssignmentNotification() async {
    try {
      final assignments = await ref.read(activeAssignmentsProvider.future);
      final active = assignments
          .where((a) =>
              a.status == StudentAssignmentStatus.pending ||
              a.status == StudentAssignmentStatus.inProgress ||
              a.status == StudentAssignmentStatus.overdue)
          .toList();
      if (active.isNotEmpty && !_hasShownAssignmentNotif) {
        _hasShownAssignmentNotif = true;
        final settings = ref.read(systemSettingsProvider).valueOrNull ??
            SystemSettings.defaults();
        if (settings.notifAssignment) {
          ref.read(assignmentNotificationEventProvider.notifier).state =
              AssignmentNotificationEvent(
            count: active.length,
            assignmentId:
                active.length == 1 ? active.first.assignmentId : null,
          );
        }
      }
    } catch (_) {
      // Silently fail — assignment notification is non-critical
    }
  }

  // ── League tier helpers ───────────────────────────────────────

  static Color _leagueTierColor(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => Colors.brown,
      LeagueTier.silver => Colors.grey,
      LeagueTier.gold => Colors.amber,
      LeagueTier.platinum => Colors.blueGrey,
      LeagueTier.diamond => Colors.cyan,
    };
  }

  static String _leagueTierEmoji(LeagueTier tier) {
    return switch (tier) {
      LeagueTier.bronze => '🥉',
      LeagueTier.silver => '🥈',
      LeagueTier.gold => '🥇',
      LeagueTier.platinum => '💎',
      LeagueTier.diamond => '👑',
    };
  }
}
```

- [ ] **Step 2: Verify file compiles**

Run: `dart analyze lib/presentation/widgets/common/notification_listener.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/widgets/common/notification_listener.dart
git commit -m "refactor: rewrite AppNotificationListener to use overlay manager"
```

---

### Task 4: Delete Old Dialog Files

**Files:**
- Delete: `lib/presentation/widgets/common/streak_event_dialog.dart`
- Delete: `lib/presentation/widgets/common/badge_earned_dialog.dart`
- Delete: `lib/presentation/widgets/common/assignment_notification_dialog.dart`

- [ ] **Step 1: Verify no other files import these dialogs**

Run:
```bash
grep -r "streak_event_dialog" lib/ --include="*.dart" -l
grep -r "badge_earned_dialog" lib/ --include="*.dart" -l
grep -r "assignment_notification_dialog" lib/ --include="*.dart" -l
```

Expected: Only `notification_listener.dart` should have imported these. After Task 3, those imports are already removed.

- [ ] **Step 2: Delete the files**

```bash
rm lib/presentation/widgets/common/streak_event_dialog.dart
rm lib/presentation/widgets/common/badge_earned_dialog.dart
rm lib/presentation/widgets/common/assignment_notification_dialog.dart
```

- [ ] **Step 3: Run full analysis**

Run: `dart analyze lib/`
Expected: No errors related to deleted files

- [ ] **Step 4: Commit**

```bash
git add -u lib/presentation/widgets/common/streak_event_dialog.dart \
           lib/presentation/widgets/common/badge_earned_dialog.dart \
           lib/presentation/widgets/common/assignment_notification_dialog.dart
git commit -m "chore: remove old individual notification dialog files"
```

---

### Task 5: Verify Full Build and Manual Test

- [ ] **Step 1: Run full analysis**

Run: `dart analyze lib/`
Expected: No errors

- [ ] **Step 2: Run Flutter build (web)**

Run: `flutter build web --release`
Expected: Build succeeds

- [ ] **Step 3: Commit any fixups**

If analysis or build revealed issues, fix them and commit:

```bash
git add -A
git commit -m "fix: address notification overlay build issues"
```
