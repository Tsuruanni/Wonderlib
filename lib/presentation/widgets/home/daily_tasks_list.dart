import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:readeng/app/theme.dart';
import 'package:readeng/presentation/providers/daily_goal_provider.dart';

/// Displays the list of daily tasks with progress
class DailyTasksList extends StatelessWidget {
  final DailyGoalState state;

  const DailyTasksList({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TaskRow(
          icon: Icons.style_rounded,
          iconColor: AppColors.gemBlue,
          label: 'Daily Review',
          isCompleted: state.dailyReviewCompleted,
          progressText: state.dailyReviewCompleted ? 'Done' : 'Start',
        ),
        const SizedBox(height: 10),
        _TaskRow(
          icon: Icons.auto_stories_rounded,
          iconColor: AppColors.primary,
          label: 'Read ${state.wordsGoal} words',
          isCompleted: state.isReadingGoalCompleted,
          progressText: '${state.wordsReadToday}/${state.wordsGoal}',
        ),
        const SizedBox(height: 10),
        _TaskRow(
          icon: Icons.quiz_rounded,
          iconColor: AppColors.wasp,
          label: 'Answer ${state.answersGoal} questions',
          isCompleted: state.isActivityGoalCompleted,
          progressText: '${state.correctAnswersToday}/${state.answersGoal}',
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isCompleted;
  final String progressText;

  const _TaskRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isCompleted,
    required this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Task icon
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.primary.withValues(alpha: 0.15)
                : iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : icon,
            size: 16,
            color: isCompleted ? AppColors.primary : iconColor,
          ),
        ),
        const SizedBox(width: 10),

        // Label
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isCompleted ? AppColors.neutralText : AppColors.black,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.neutralText,
            ),
          ),
        ),

        // Progress badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.primaryBackground
                : AppColors.neutral.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            progressText,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isCompleted ? AppColors.primary : AppColors.neutralText,
            ),
          ),
        ),
      ],
    );
  }
}
