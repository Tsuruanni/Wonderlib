import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/router.dart';
import 'package:owlio/app/theme.dart';
import 'package:owlio/domain/entities/daily_quest.dart';

/// Renders daily quest rows in a styled card.
class DailyQuestList extends StatelessWidget {
  const DailyQuestList({
    super.key,
    required this.progress,
  });

  final List<DailyQuestProgress> progress;

  @override
  Widget build(BuildContext context) {
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
            for (var i = 0; i < progress.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.neutral.withValues(alpha: 0.6),
                ),
              _QuestRow(progress: progress[i]),
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
    final route = _questRoute(quest.questType);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: route != null ? () => context.go(route!) : null,
      child: Padding(
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
      ),
    );
  }

  String? _questRoute(String questType) {
    return switch (questType) {
      'read_chapters' => AppRoutes.library,
      'vocab_session' => AppRoutes.vocabularyDailyReview,
      _ => null,
    };
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

