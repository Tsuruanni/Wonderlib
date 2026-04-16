import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/router.dart';
import 'package:owlio/app/theme.dart';
import 'package:owlio/domain/entities/daily_quest.dart';
import '../../utils/app_icons.dart';
import '../common/app_progress_bar.dart';

/// Renders daily quest rows in badges island style — no outer card,
/// each quest is an individual row with a colored tile on the left.
class DailyQuestList extends StatelessWidget {
  const DailyQuestList({
    super.key,
    required this.progress,
  });

  final List<DailyQuestProgress> progress;

  @override
  Widget build(BuildContext context) {
    final allComplete =
        progress.isNotEmpty && progress.every((q) => q.isCompleted);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
          if (allComplete) ...[
            _AllCompleteBanner(),
            const SizedBox(height: 12),
          ],
          for (int i = 0; i < progress.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _QuestRow(progress: progress[i]),
          ],
        ],
      ),
    );
  }
}

class _AllCompleteBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AppIcons.check(size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You've completed all quests for today!",
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.progress});

  final DailyQuestProgress progress;

  ({Color base, Color shadow}) _rewardColors(QuestRewardType rewardType) {
    return switch (rewardType) {
      QuestRewardType.xp => (base: AppColors.primary, shadow: AppColors.primaryDark),
      QuestRewardType.coins => (base: AppColors.wasp, shadow: AppColors.waspDark),
      QuestRewardType.cardPack => (base: AppColors.gemBlue, shadow: const Color(0xFF1899D6)),
    };
  }

  String? _questRoute(String questType) {
    return switch (questType) {
      'read_chapters' => AppRoutes.library,
      'vocab_session' => AppRoutes.vocabularyDailyReview,
      _ => null,
    };
  }

  String _displayTitle(DailyQuest quest) {
    if (quest.questType == 'vocab_session' || quest.questType == 'review_words') {
      return 'Do your Daily Review';
    }
    return quest.title;
  }

  Widget _buildRewardTile(DailyQuest quest, bool isCompleted) {
    if (isCompleted) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.wasp,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: AppColors.waspDark, offset: Offset(0, 4), blurRadius: 0),
          ],
          border: Border.all(color: AppColors.waspDark, width: 1.5),
        ),
        child: Center(child: AppIcons.check(size: 28)),
      );
    }
    final colors = _rewardColors(quest.rewardType);
    final icon = switch (quest.rewardType) {
      QuestRewardType.xp => AppIcons.xp(size: 24),
      QuestRewardType.coins => AppIcons.gem(size: 24),
      QuestRewardType.cardPack => AppIcons.card(size: 24),
    };
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: colors.base,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: colors.shadow, offset: const Offset(0, 4), blurRadius: 0),
        ],
        border: Border.all(color: colors.shadow, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 2),
          Text(
            '${quest.rewardAmount}',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final isCompleted = progress.isCompleted;
    final currentValue = progress.currentValue;
    final goalValue = quest.goalValue;
    final ratio = goalValue > 0 ? (currentValue / goalValue).clamp(0.0, 1.0) : 0.0;
    final route = _questRoute(quest.questType);
    final rewardColors = isCompleted
        ? (base: AppColors.wasp, shadow: AppColors.waspDark)
        : _rewardColors(quest.rewardType);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: route != null ? () => context.go(route) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayTitle(quest),
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isCompleted ? AppColors.neutralText : AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                AppProgressBar(
                  progress: ratio,
                  height: 12,
                  fillColor: rewardColors.base,
                  fillShadow: rewardColors.shadow,
                ),
                const SizedBox(height: 5),
                Text(
                  '$currentValue / $goalValue',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _buildRewardTile(quest, isCompleted),
        ],
      ),
    );
  }
}
