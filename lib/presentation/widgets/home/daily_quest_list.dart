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
    final sorted = [...progress]
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return a.quest.rewardAmount.compareTo(b.quest.rewardAmount);
      });

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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.neutral),
            ),
          ],
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.neutral),
              ),
            _QuestRow(progress: sorted[i]),
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
      QuestRewardType.coins =>
        (base: AppColors.streakOrange, shadow: const Color(0xFFC76A00)),
      QuestRewardType.cardPack =>
        (base: AppColors.cardEpic, shadow: AppColors.cardEpicDark),
    };
  }

  String? _questRoute(String questType) {
    return switch (questType) {
      'read_chapters' => AppRoutes.library,
      'daily_review' => AppRoutes.vocabularyDailyReview,
      'vocab_session' => AppRoutes.vocabularyDailyReview,
      _ => null,
    };
  }

  Widget _buildRewardContent(DailyQuest quest, bool isCompleted) {
    final colors = isCompleted
        ? (base: AppColors.primary, shadow: AppColors.primaryDark)
        : _rewardColors(quest.rewardType);
    if (isCompleted) {
      return AppIcons.check(size: 34);
    }
    final icon = switch (quest.rewardType) {
      QuestRewardType.coins => AppIcons.gem(size: 34),
      QuestRewardType.cardPack => AppIcons.card(size: 34),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          '×${quest.rewardAmount}',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: colors.shadow,
          ),
        ),
      ],
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
    final barColors = isCompleted
        ? (base: AppColors.wasp, shadow: AppColors.waspDark)
        : _rewardColors(quest.rewardType);
    final rewardColors = isCompleted
        ? (base: AppColors.primary, shadow: AppColors.primaryDark)
        : _rewardColors(quest.rewardType);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: route != null ? () => context.go(route) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: isCompleted
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: quest.title,
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutralText,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.neutralText,
                                decorationThickness: 2,
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: AppIcons.check(size: 18),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        quest.title,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
              ),
              if (!isCompleted) ...[
                const SizedBox(width: 12),
                _buildRewardContent(quest, false),
              ],
            ],
          ),
          if (isCompleted || currentValue > 0) ...[
            const SizedBox(height: 12),
            AppProgressBar(
              progress: ratio,
              height: 8,
              fillColor: barColors.base,
              fillShadow: barColors.shadow,
            ),
          ],
        ],
      ),
    );
  }
}
