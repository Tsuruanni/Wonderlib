import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/router.dart';
import 'package:owlio/app/theme.dart';
import 'package:owlio/domain/entities/daily_quest.dart';
import 'package:owlio/domain/entities/student_assignment.dart';
import 'package:owlio/domain/usecases/daily_quest/claim_daily_bonus_usecase.dart';
import 'package:owlio/presentation/providers/auth_provider.dart';
import 'package:owlio/presentation/providers/daily_quest_provider.dart';
import 'package:owlio/presentation/providers/student_assignment_provider.dart';
import 'package:owlio/presentation/providers/usecase_providers.dart';
import 'package:owlio/presentation/providers/user_provider.dart';

import '../../../core/utils/app_clock.dart';

/// Renders the unified daily quest card: teacher assignments + quest rows +
/// bonus reward row.
class DailyQuestList extends ConsumerStatefulWidget {
  const DailyQuestList({
    super.key,
    required this.progress,
    required this.bonusClaimed,
  });

  final List<DailyQuestProgress> progress;
  final bool bonusClaimed;

  @override
  ConsumerState<DailyQuestList> createState() => _DailyQuestListState();
}

class _DailyQuestListState extends ConsumerState<DailyQuestList> {
  bool _isClaiming = false;
  bool _justClaimed = false;

  Future<void> _claimBonus() async {
    if (_isClaiming) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isClaiming = true);

    final useCase = ref.read(claimDailyBonusUseCaseProvider);
    final result = await useCase(ClaimDailyBonusParams(userId: userId));

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (_) {
        if (mounted) {
          setState(() => _justClaimed = true);
          ref.invalidate(dailyQuestProgressProvider);
          ref.invalidate(dailyBonusClaimedProvider);
          ref.read(userControllerProvider.notifier).refreshProfileOnly();
        }
      },
    );

    if (mounted) setState(() => _isClaiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(activeAssignmentsProvider);
    final assignments = assignmentsAsync.valueOrNull ?? [];

    final List<Widget> rows = [];

    // Assignment rows (teacher-assigned tasks)
    for (final assignment in assignments) {
      rows.add(_AssignmentQuestRow(assignment: assignment));
    }

    if (assignments.isNotEmpty) {
      rows.add(const _ThickDivider());
    }

    // Daily quest rows
    for (final questProgress in widget.progress) {
      rows.add(_QuestRow(progress: questProgress));
    }

    // Bonus reward row
    rows.add(const _ThickDivider());
    rows.add(_BonusRow(
      allComplete: widget.progress.isNotEmpty &&
          widget.progress.every((q) => q.isCompleted),
      claimed: widget.bonusClaimed || _justClaimed,
      isClaiming: _isClaiming,
      onClaim: _claimBonus,
    ),);

    return DecoratedBox(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0 &&
                  rows[i] is! _ThickDivider &&
                  rows[i - 1] is! _ThickDivider)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.neutral.withValues(alpha: 0.6),
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thick divider separating sections
// ---------------------------------------------------------------------------

class _ThickDivider extends StatelessWidget {
  const _ThickDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 3, color: AppColors.neutral);
  }
}

// ---------------------------------------------------------------------------
// Single daily quest row
// ---------------------------------------------------------------------------

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.progress});

  final DailyQuestProgress progress;

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final isCompleted = progress.isCompleted;
    final currentValue = progress.currentValue;
    final goalValue = quest.goalValue;
    final progressFraction =
        goalValue > 0 ? (currentValue / goalValue).clamp(0.0, 1.0) : 0.0;

    final rewardText = _rewardText(quest);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.wasp.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 24,
                      color: AppColors.waspDark,
                    )
                  : Text(
                      quest.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Title + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.neutralText : AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                _ProgressBar(
                  progress: progressFraction,
                  progressText: '$currentValue / $goalValue',
                  isCompleted: isCompleted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Reward badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _rewardColor(quest).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rewardText,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _rewardColor(quest),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _rewardText(DailyQuest quest) {
    return switch (quest.rewardType) {
      QuestRewardType.xp => '+${quest.rewardAmount} XP',
      QuestRewardType.coins => '+${quest.rewardAmount} 🪙',
      QuestRewardType.cardPack => '+${quest.rewardAmount} 📦',
    };
  }

  Color _rewardColor(DailyQuest quest) {
    return switch (quest.rewardType) {
      QuestRewardType.xp => AppColors.primary,
      QuestRewardType.coins => AppColors.wasp,
      QuestRewardType.cardPack => AppColors.gemBlue,
    };
  }
}

// ---------------------------------------------------------------------------
// Bonus reward row (locked / claimable / claimed)
// ---------------------------------------------------------------------------

class _BonusRow extends StatelessWidget {
  const _BonusRow({
    required this.allComplete,
    required this.claimed,
    required this.isClaiming,
    required this.onClaim,
  });

  final bool allComplete;
  final bool claimed;
  final bool isClaiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    if (claimed) {
      return Container(
        color: AppColors.primary.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bonus claimed! +1 pack',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralText,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.style_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '+1',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (allComplete) {
      return GestureDetector(
        onTap: isClaiming ? null : onClaim,
        child: Container(
          color: AppColors.wasp.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.wasp.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: isClaiming
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.wasp,
                        ),
                      )
                    : const Text(
                        '🎁',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24),
                      ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.05, 1.05),
                    duration: 800.ms,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claim Reward!',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.waspDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All quests complete! Claim your card pack',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.wasp,
              ),
            ],
          ),
        ),
      );
    }

    // Locked — not all quests done yet
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.neutral.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 20,
              color: AppColors.neutralText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Complete all quests → Card Pack',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralText,
              ),
            ),
          ),
          const Text('📦', style: TextStyle(fontSize: 22)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar with centered text overlay
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.progressText,
    required this.isCompleted,
    this.fillColor,
  });

  final double progress;
  final String progressText;
  final bool isCompleted;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final fill = fillColor ?? AppColors.wasp;
    final track = AppColors.neutral.withValues(alpha: 0.5);

    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          // Track
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Fill
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Text overlay
          Center(
            child: Text(
              progressText,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: progress > 0.5 ? AppColors.white : AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assignment quest row (teacher-assigned tasks)
// ---------------------------------------------------------------------------

class _AssignmentQuestRow extends StatelessWidget {
  const _AssignmentQuestRow({required this.assignment});

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

    final dueText = _buildDueText(assignment);

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.studentAssignmentDetailPath(assignment.assignmentId),
      ),
      child: Container(
        color: iconColor.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Circle icon
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

            // Title + progress bar
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
                      color:
                          isCompleted ? AppColors.neutralText : AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ProgressBar(
                    progress: progress,
                    progressText: dueText,
                    isCompleted: isCompleted,
                    fillColor: isCompleted ? AppColors.primary : iconColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Arrow / check
            Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              size: isCompleted ? 22 : 16,
              color: isCompleted ? AppColors.primary : AppColors.neutralText,
            ),
          ],
        ),
      ),
    );
  }

  String _buildDueText(StudentAssignment a) {
    if (a.status == StudentAssignmentStatus.completed) return 'Completed';
    final daysLeft = a.dueDate.difference(AppClock.now()).inDays;
    if (daysLeft < 0) return 'Overdue';
    if (daysLeft == 0) return 'Due today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }
}
