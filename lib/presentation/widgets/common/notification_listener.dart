import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/entities/streak_result.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../../domain/entities/system_settings.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_quest_provider.dart';
import '../../providers/student_assignment_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../providers/user_provider.dart';
import 'notification_card.dart';
import 'notification_overlay_manager.dart';

/// Listens to all notification event providers and shows overlay notification
/// cards via [NotificationOverlayManager]. Wraps the app root in app.dart.
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

    ref.listen<QuestCompletionEvent?>(
        questCompletionEventProvider, (previous, next) {
      if (next != null) _showQuestComplete(next);
    });

    // Fire assignment notification AFTER user is fully loaded (students only).
    // This ensures streak/badge/league notifications fire first since they
    // are triggered during UserController._loadUserById().
    {
      final isTeacher = ref.watch(isTeacherProvider);
      if (!isTeacher) {
        // Keep dailyQuestProgressProvider alive so invalidations from
        // activity completions trigger a refetch and fire the quest
        // completion event — even if QuestsScreen hasn't been visited yet.
        ref.watch(dailyQuestProgressProvider);
        ref.listen<AsyncValue<User?>>(userControllerProvider, (previous, next) {
          // Reset flag on logout so next login can show notification
          if (next is AsyncData<User?> && next.value == null) {
            _hasShownAssignmentNotif = false;
            ref.read(assignmentNotificationEventProvider.notifier).state = null;
            ref.read(questCompletionEventProvider.notifier).state = null;
            _manager.dismissAll();
            return;
          }
          if (_hasShownAssignmentNotif) return;
          // Wait for user to finish loading (streak/badge/league already fired)
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

  OverlayState? get _overlay => rootNavigatorKey.currentState?.overlay;

  void _showLevelUp(LevelUpEvent event) {
    final overlay = _overlay;
    if (overlay == null) return;
    _manager.show(
      overlay: overlay,
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
    final overlay = _overlay;
    if (overlay == null) return;
    _manager.show(
      overlay: overlay,
      type: NotificationType.leagueChange,
      data: event,
      cardBuilder: (dismiss) => NotificationCard.leagueChange(
        oldTier: event.oldTier,
        newTier: event.newTier,
        onDismiss: dismiss,
      ),
      onDismiss: () {
        ref.read(leagueTierChangeEventProvider.notifier).state = null;
      },
    );
  }

  void _showStreakEvent(StreakResult result) {
    final overlay = _overlay;
    if (overlay == null) return;

    // Determine streak type by priority:
    // 1. milestone  2. freeze  3. broken  4. extended
    final NotificationType type;
    final Widget Function(VoidCallback dismiss) cardBuilder;

    if (result.milestoneBonusXp > 0) {
      type = NotificationType.streakMilestone;
      cardBuilder = (dismiss) => NotificationCard.streakMilestone(
            newStreak: result.newStreak,
            bonusXp: result.milestoneBonusXp,
            onDismiss: dismiss,
          );
    } else if (result.freezeUsed && !result.streakBroken) {
      type = NotificationType.streakFreeze;
      cardBuilder = (dismiss) => NotificationCard.streakFreeze(
            newStreak: result.newStreak,
            freezesRemaining: result.freezesRemaining,
            onDismiss: dismiss,
          );
    } else if (result.streakBroken) {
      type = NotificationType.streakBroken;
      cardBuilder = (dismiss) => NotificationCard.streakBroken(
            previousStreak: result.previousStreak,
            freezesConsumed: result.freezesConsumed,
            onDismiss: dismiss,
          );
    } else {
      type = NotificationType.streakExtended;
      cardBuilder = (dismiss) => NotificationCard.streakExtended(
            newStreak: result.newStreak,
            previousStreak: result.previousStreak,
            onDismiss: dismiss,
          );
    }

    _manager.show(
      overlay: overlay,
      type: type,
      data: result,
      cardBuilder: cardBuilder,
      onDismiss: () {
        ref.read(streakEventProvider.notifier).state = null;
      },
    );
  }

  void _showBadgeEarned(BadgeEarnedEvent event) {
    final overlay = _overlay;
    if (overlay == null) return;
    _manager.show(
      overlay: overlay,
      type: NotificationType.badgeEarned,
      data: event,
      cardBuilder: (dismiss) => NotificationCard.badgeEarned(
        badges: event.badges,
        onDismiss: dismiss,
      ),
      onDismiss: () {
        ref.read(badgeEarnedEventProvider.notifier).state = null;
      },
    );
  }

  void _showAssignment(AssignmentNotificationEvent event) {
    final overlay = _overlay;
    if (overlay == null) return;
    _manager.show(
      overlay: overlay,
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

  void _showQuestComplete(QuestCompletionEvent event) {
    final overlay = _overlay;
    if (overlay == null) return;

    // Show individual quest notification (skip if all quests just completed —
    // the all-quests card replaces it).
    if (!event.allQuestsComplete) {
      _manager.show(
        overlay: overlay,
        type: NotificationType.questComplete,
        data: event,
        cardBuilder: (dismiss) => NotificationCard.questComplete(
          quests: event.completedQuests,
          allQuestsComplete: false,
          onDismiss: dismiss,
        ),
        onDismiss: () {
          ref.read(questCompletionEventProvider.notifier).state = null;
        },
      );
      return;
    }

    // All quests done — show special card with Claim button.
    _manager.show(
      overlay: overlay,
      type: NotificationType.allQuestsComplete,
      data: event,
      cardBuilder: (dismiss) => NotificationCard.allQuestsComplete(
        onClaim: () async {
          dismiss();
          final controller =
              ref.read(dailyQuestControllerProvider.notifier);
          final error = await controller.claimBonus();
          if (error == null) return;
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
        onDismiss: dismiss,
      ),
      onDismiss: () {
        ref.read(questCompletionEventProvider.notifier).state = null;
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
              a.status == StudentAssignmentStatus.overdue,)
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
}
