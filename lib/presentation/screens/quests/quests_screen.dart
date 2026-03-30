import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/app_clock.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/daily_quest.dart';
import '../../../domain/entities/student_assignment.dart';
import '../../providers/badge_provider.dart';
import '../../providers/daily_quest_provider.dart';
import '../../providers/student_assignment_provider.dart';
import '../../widgets/common/top_navbar.dart';
import '../../widgets/home/daily_quest_list.dart';
import '../../widgets/home/quest_completion_dialog.dart';

// ---------------------------------------------------------------------------
// Quests Screen — daily quests, badges gallery, monthly placeholders
// ---------------------------------------------------------------------------

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dailyQuestProgressProvider);
    final bonusClaimed = ref.watch(dailyBonusClaimedProvider).valueOrNull ?? false;

    // Listen for newly completed quests and show dialog
    ref.listen<AsyncValue<List<DailyQuestProgress>>>(
      dailyQuestProgressProvider,
      (prev, next) {
        final nextData = next.valueOrNull ?? [];
        final newlyCompleted =
            nextData.where((q) => q.newlyCompleted).toList();
        if (newlyCompleted.isNotEmpty) {
          final allComplete = nextData.every((q) => q.isCompleted);
          QuestCompletionDialog.show(
            context,
            completedQuests: newlyCompleted,
            allQuestsComplete: allComplete && !bonusClaimed,
          );
        }
      },
    );

    final progress = progressAsync.valueOrNull ?? [];
    // RightInfoPanel is shown at ≥1000px — monthly cards live there
    final showRightPanel = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Monthly Quest — only when sidebar is hidden
                      if (!showRightPanel) ...[
                        const _MonthlyQuestCard(),
                        const SizedBox(height: 24),
                      ],
                      // Assignments
                      const _AssignmentsSection(),
                      // Daily Quests
                      const _DailyQuestsHeader(),
                      const SizedBox(height: 12),
                      DailyQuestList(
                        progress: progress,
                        bonusClaimed: bonusClaimed,
                      ),
                      const SizedBox(height: 24),
                      // Badges
                      const _BadgesSection(),
                      const SizedBox(height: 24),
                      // Monthly Badges — only when sidebar is hidden
                      if (!showRightPanel) ...[
                        const _MonthlyBadgesCard(),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assignments Section — teacher-assigned tasks
// ---------------------------------------------------------------------------

class _AssignmentsSection extends ConsumerWidget {
  const _AssignmentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(activeAssignmentsProvider);
    final assignments = assignmentsAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Assignments',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${assignments.length}',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const Spacer(),
            if (assignments.isNotEmpty)
              GestureDetector(
                onTap: () => context.push(AppRoutes.studentAssignments),
                child: Text(
                  'VIEW ALL',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (assignments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neutral, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.neutral,
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined,
                    size: 32, color: AppColors.neutralText),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No assignments from your teacher',
                    style: GoogleFonts.nunito(
                      color: AppColors.neutralText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.neutral,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                for (int i = 0; i < assignments.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.neutral.withValues(alpha: 0.6),
                    ),
                  _AssignmentRow(assignment: assignments[i]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.assignment});
  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final isCompleted = assignment.status == StudentAssignmentStatus.completed;
    final progress = (assignment.progress / 100).clamp(0.0, 1.0);

    final IconData icon;
    final Color iconColor;
    switch (assignment.type) {
      case StudentAssignmentType.book:
        icon = Icons.auto_stories_rounded;
        iconColor = AppColors.gemBlue;
      case StudentAssignmentType.vocabulary:
        icon = Icons.abc_rounded;
        iconColor = AppColors.secondary;
      case StudentAssignmentType.unit:
        icon = Icons.route;
        iconColor = AppColors.streakOrange;
    }

    final daysLeft = assignment.dueDate.difference(AppClock.now()).inDays;
    final String dueText;
    if (isCompleted) {
      dueText = 'Completed';
    } else if (daysLeft < 0) {
      dueText = 'Overdue';
    } else if (daysLeft == 0) {
      dueText = 'Due today';
    } else if (daysLeft == 1) {
      dueText = '1 day left';
    } else {
      dueText = '$daysLeft days left';
    }

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.studentAssignmentDetailPath(assignment.assignmentId),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                size: 24,
                color: isCompleted ? AppColors.primary : iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCompleted ? AppColors.neutralText : AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.neutral,
                            color: isCompleted ? AppColors.primary : iconColor,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dueText,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: daysLeft < 0 && !isCompleted
                              ? AppColors.danger
                              : AppColors.neutralText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              size: isCompleted ? 22 : 20,
              color: isCompleted ? AppColors.primary : AppColors.neutralText,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly Quest Card (placeholder — hardcoded)
// ---------------------------------------------------------------------------

class _MonthlyQuestCard extends StatelessWidget {
  const _MonthlyQuestCard();

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();
    final monthName = DateFormat('MMMM').format(now).toUpperCase();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysLeft = lastDay.difference(now).inDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.streakOrange,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFC76A00),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month chip + countdown row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  monthName,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$daysLeft DAYS',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            '${DateFormat('MMMM').format(now)} Quest',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Inner progress card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete 20 quests',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                SizedBox(
                  height: 20,
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.neutral.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      // Fill (0 progress)
                      FractionallySizedBox(
                        widthFactor: 0,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.streakOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '0 / 20',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Quests Header
// ---------------------------------------------------------------------------

class _DailyQuestsHeader extends StatelessWidget {
  const _DailyQuestsHeader();

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final hoursLeft = midnight.difference(now).inHours;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Daily Quests',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              '$hoursLeft HOURS',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badges Section
// ---------------------------------------------------------------------------

class _BadgesSection extends ConsumerWidget {
  const _BadgesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBadgesAsync = ref.watch(allBadgesProvider);
    final userBadgesAsync = ref.watch(userBadgesProvider);

    final allBadges = allBadgesAsync.valueOrNull ?? [];
    final userBadges = userBadgesAsync.valueOrNull ?? [];
    final earnedBadgeIds = userBadges.map((ub) => ub.badgeId).toSet();

    final earned = allBadges.where((b) => earnedBadgeIds.contains(b.id)).toList();
    final unearned =
        allBadges.where((b) => !earnedBadgeIds.contains(b.id)).toList();

    final total = allBadges.length;
    final earnedCount = earned.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Badges',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$earnedCount / $total',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Loading state
        if (allBadgesAsync.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
          )
        else ...[
          // Earned badges
          if (earned.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: earned
                  .map((badge) => _BadgeTile(badge: badge, isEarned: true))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Unearned badges
          if (unearned.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: unearned
                  .map((badge) => _BadgeTile(badge: badge, isEarned: false))
                  .toList(),
            ),

          // Empty state
          if (allBadges.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No badges available yet',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralText,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badge Tile
// ---------------------------------------------------------------------------

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.isEarned,
  });

  final Badge badge;
  final bool isEarned;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEarned ? 1.0 : 0.4,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEarned ? AppColors.primary : AppColors.neutral,
            width: isEarned ? 2 : 1.5,
          ),
          boxShadow: isEarned
              ? const [
                  BoxShadow(
                    color: AppColors.primaryDark,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji icon
            Text(
              badge.icon ?? '',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),

            // Name
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),

            // Check icon for earned / description for unearned
            if (isEarned) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ] else if (badge.description != null &&
                badge.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                badge.description!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly Badges Card (placeholder)
// ---------------------------------------------------------------------------

class _MonthlyBadgesCard extends StatelessWidget {
  const _MonthlyBadgesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neutral,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            'MONTHLY BADGES',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralText,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.streakOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.military_tech_rounded,
              size: 32,
              color: AppColors.streakOrange,
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            'Earn your first badge!',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            'Complete monthly challenges to earn exclusive badges and rewards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neutralText,
            ),
          ),
        ],
      ),
    );
  }
}
