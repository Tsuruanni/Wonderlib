import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:owlio/app/theme.dart';
import 'package:owlio/domain/entities/daily_quest.dart';

/// Dialog shown when one or more daily quests are completed.
class QuestCompletionDialog extends StatelessWidget {
  const QuestCompletionDialog({
    super.key,
    required this.completedQuests,
    required this.allQuestsComplete,
  });

  final List<DailyQuestProgress> completedQuests;
  final bool allQuestsComplete;

  static void show(
    BuildContext context, {
    required List<DailyQuestProgress> completedQuests,
    required bool allQuestsComplete,
  }) {
    showDialog(
      context: context,
      builder: (_) => QuestCompletionDialog(
        completedQuests: completedQuests,
        allQuestsComplete: allQuestsComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.white,
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Quest Complete!',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Completed quest rows
          ...completedQuests.map((progress) => _QuestRewardRow(progress: progress)),

          // All quests complete bonus section
          if (allQuestsComplete) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.waspBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.wasp.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All quests complete! Claim your bonus card pack!',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.waspDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestRewardRow extends StatelessWidget {
  const _QuestRewardRow({required this.progress});

  final DailyQuestProgress progress;

  @override
  Widget build(BuildContext context) {
    final quest = progress.quest;
    final (rewardText, rewardColor) = _rewardTextAndColor(quest);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Quest icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rewardColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                quest.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Title
          Expanded(
            child: Text(
              quest.title,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reward badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rewardColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rewardText,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: rewardColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _rewardTextAndColor(DailyQuest quest) {
    return switch (quest.rewardType) {
      QuestRewardType.xp => (
          '+${quest.rewardAmount} XP earned!',
          AppColors.primary,
        ),
      QuestRewardType.coins => (
          '+${quest.rewardAmount} coins earned!',
          AppColors.wasp,
        ),
      QuestRewardType.cardPack => (
          '+${quest.rewardAmount} card pack earned!',
          AppColors.cardEpic,
        ),
    };
  }
}
