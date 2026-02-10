import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readeng/app/router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readeng/app/theme.dart';
import 'package:readeng/domain/entities/student_assignment.dart';
import 'package:readeng/domain/usecases/card/claim_daily_quest_pack_usecase.dart';
import 'package:readeng/presentation/providers/auth_provider.dart';
import 'package:readeng/presentation/providers/daily_goal_provider.dart';
import 'package:readeng/presentation/providers/usecase_providers.dart';
import 'package:readeng/presentation/providers/user_provider.dart';

/// Displays daily quests and assignment quests inside a single unified card
class DailyTasksList extends ConsumerStatefulWidget {
  final DailyGoalState state;
  final List<StudentAssignment> assignments;

  const DailyTasksList({
    super.key,
    required this.state,
    this.assignments = const [],
  });

  @override
  ConsumerState<DailyTasksList> createState() => _DailyTasksListState();
}

class _DailyTasksListState extends ConsumerState<DailyTasksList> {
  bool _isClaiming = false;
  bool _justClaimed = false;

  Future<void> _claimPack() async {
    if (_isClaiming) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isClaiming = true);

    final useCase = ref.read(claimDailyQuestPackUseCaseProvider);
    final result = await useCase(ClaimDailyQuestPackParams(userId: userId));

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (newPackCount) {
        if (mounted) {
          setState(() => _justClaimed = true);
          // Refresh providers
          ref.invalidate(dailyGoalProvider);
          ref.invalidate(dailyQuestPackClaimedProvider);
          ref.read(userControllerProvider.notifier).refresh();
        }
      },
    );

    if (mounted) setState(() => _isClaiming = false);
  }

  @override
  Widget build(BuildContext context) {
    // Build all rows: assignments first, then daily quests
    final List<Widget> rows = [];

    // Assignment rows
    for (var i = 0; i < widget.assignments.length; i++) {
      rows.add(_AssignmentQuestRow(assignment: widget.assignments[i]));
    }

    // Simple divider between assignments and daily quests
    if (widget.assignments.isNotEmpty) {
      rows.add(const _ThickDivider());
    }

    // Daily quest rows
    rows.add(_QuestRow(
      icon: Icons.spellcheck_rounded,
      iconColor: AppColors.secondary,
      title: 'Review daily vocab',
      progress: widget.state.dailyReviewCompleted ? 1.0 : 0.0,
      progressText: widget.state.dailyReviewCompleted ? '1 / 1' : '0 / 1',
      isCompleted: widget.state.dailyReviewCompleted,
    ));
    rows.add(_QuestRow(
      icon: Icons.auto_stories_rounded,
      iconColor: AppColors.primary,
      title: 'Read ${widget.state.wordsGoal} words',
      progress: widget.state.readingProgress,
      progressText: '${widget.state.wordsReadToday} / ${widget.state.wordsGoal}',
      isCompleted: widget.state.isReadingGoalCompleted,
    ));
    rows.add(_QuestRow(
      icon: Icons.star_rounded,
      iconColor: AppColors.gemBlue,
      title: 'Answer ${widget.state.answersGoal} questions',
      progress: widget.state.activityProgress,
      progressText: '${widget.state.correctAnswersToday} / ${widget.state.answersGoal}',
      isCompleted: widget.state.isActivityGoalCompleted,
    ));

    // Treasure reward row
    rows.add(const _ThickDivider());
    rows.add(_buildRewardRow());

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neutral, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral,
            offset: const Offset(0, 4),
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
              if (i > 0 && rows[i] is! _ThickDivider && rows[i - 1] is! _ThickDivider)
                Divider(height: 1, thickness: 1, color: AppColors.neutral.withValues(alpha: 0.6)),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRewardRow() {
    final allDone = widget.state.allTasksCompleted;
    final claimed = widget.state.packClaimed || _justClaimed;

    if (claimed) {
      // Already claimed today
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
                'Pack claimed!',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralText,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.style_rounded, size: 16, color: AppColors.primary),
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

    if (allDone) {
      // All quests done — claim available
      return GestureDetector(
        onTap: _isClaiming ? null : _claimPack,
        child: Container(
          color: AppColors.wasp.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Pulsing treasure chest
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.wasp.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: _isClaiming
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wasp),
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
                      'Claim your reward!',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.waspDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to get a free Mythic Pack',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutralText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.wasp,
              ),
            ],
          ),
        ),
      );
    }

    // Not all quests done — show locked reward
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
              'Complete all quests for a Mythic Pack',
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

/// Thicker divider to separate assignment rows from daily quest rows
class _ThickDivider extends StatelessWidget {
  const _ThickDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 3, color: AppColors.neutral);
  }
}

/// A single quest row (no border — lives inside the unified card)
class _QuestRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final double progress;
  final String progressText;
  final bool isCompleted;

  const _QuestRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.progress,
    required this.progressText,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Circle icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.wasp.withValues(alpha: 0.15)
                  : iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              size: 24,
              color: isCompleted ? AppColors.waspDark : iconColor,
            ),
          ),
          const SizedBox(width: 12),

          // Title + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppColors.neutralText : AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                _ProgressBar(
                  progress: progress,
                  progressText: progressText,
                  isCompleted: isCompleted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Treasure chest
          Text(
            isCompleted ? '🎁' : '📦',
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

/// Reusable progress bar with centered text overlay
class _ProgressBar extends StatelessWidget {
  final double progress;
  final String progressText;
  final bool isCompleted;
  final Color? fillColor;

  const _ProgressBar({
    required this.progress,
    required this.progressText,
    required this.isCompleted,
    this.fillColor,
  });

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

/// Assignment row inside the unified card (tinted background)
class _AssignmentQuestRow extends StatelessWidget {
  final StudentAssignment assignment;
  const _AssignmentQuestRow({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final isCompleted = assignment.status == StudentAssignmentStatus.completed;
    final progress = (assignment.progress / 100).clamp(0.0, 1.0);

    // Icon & color by assignment type
    final IconData icon;
    final Color iconColor;
    switch (assignment.type) {
      case StudentAssignmentType.book:
        icon = Icons.auto_stories_rounded;
        iconColor = AppColors.gemBlue;
      case StudentAssignmentType.vocabulary:
        icon = Icons.abc_rounded;
        iconColor = AppColors.secondary;
      case StudentAssignmentType.mixed:
        icon = Icons.library_books_rounded;
        iconColor = AppColors.primary;
    }

    final dueText = _buildDueText(assignment);

    return GestureDetector(
      onTap: () => context.push(
        '${AppRoutes.studentAssignments}/${assignment.assignmentId}',
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
                      color: isCompleted ? AppColors.neutralText : AppColors.black,
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
    final daysLeft = a.dueDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return 'Overdue';
    if (daysLeft == 0) return 'Due today';
    if (daysLeft == 1) return '1 day left';
    return '$daysLeft days left';
  }
}
