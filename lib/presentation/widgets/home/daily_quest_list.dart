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

  ({Color base, Color shadow}) _colors(String questType) {
    return switch (questType) {
      'earn_xp' => (base: AppColors.primary, shadow: AppColors.primaryDark),
      'earn_combo_xp' => (
          base: AppColors.cardLegendary,
          shadow: AppColors.cardLegendaryDark
        ),
      'spend_time' => (base: AppColors.secondary, shadow: AppColors.secondaryDark),
      'complete_chapters' || 'read_chapters' => (
          base: AppColors.secondary,
          shadow: AppColors.secondaryDark
        ),
      'review_words' || 'vocab_session' => (
          base: AppColors.cardEpic,
          shadow: AppColors.cardEpicDark
        ),
      _ => (base: AppColors.gray500, shadow: AppColors.gray600),
    };
  }

  String? _questRoute(String questType) {
    return switch (questType) {
      'read_chapters' => AppRoutes.library,
      'vocab_session' => AppRoutes.vocabularyDailyReview,
      _ => null,
    };
  }

  Widget _rewardBadge(DailyQuest quest) {
    final (text, color) = switch (quest.rewardType) {
      QuestRewardType.xp => ('+${quest.rewardAmount} XP', AppColors.primary),
      QuestRewardType.coins => ('+${quest.rewardAmount} 🪙', AppColors.wasp),
      QuestRewardType.cardPack => ('+${quest.rewardAmount} 📦', AppColors.gemBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
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
    final colors = isCompleted
        ? (base: AppColors.wasp, shadow: AppColors.waspDark)
        : _colors(quest.questType);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: route != null ? () => context.go(route) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.base,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
              border: Border.all(color: colors.shadow, width: 1.5),
            ),
            child: Center(
              child: isCompleted
                  ? AppIcons.check(size: 28)
                  : Text(
                      quest.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
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
                  fillColor: colors.base,
                  fillShadow: colors.shadow,
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$currentValue / $goalValue',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray500,
                      ),
                    ),
                    _rewardBadge(quest),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
