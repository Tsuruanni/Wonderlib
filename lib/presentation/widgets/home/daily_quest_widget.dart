import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owlio/domain/entities/daily_quest.dart';
import 'package:owlio/presentation/providers/daily_quest_provider.dart';
import 'package:owlio/presentation/widgets/home/daily_quest_list.dart';
import 'package:owlio/presentation/widgets/home/quest_completion_dialog.dart';

/// Wrapper widget that watches daily quest providers and triggers the
/// completion popup when quests are newly completed.
class DailyQuestWidget extends ConsumerWidget {
  const DailyQuestWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dailyQuestProgressProvider);
    final bonusClaimed = ref.watch(dailyBonusClaimedProvider).valueOrNull ?? false;

    // Listen for newly completed quests and show popup.
    ref.listen<AsyncValue<List<DailyQuestProgress>>>(dailyQuestProgressProvider,
        (prev, next) {
      final nextData = next.valueOrNull ?? [];
      final newlyCompleted = nextData.where((q) => q.newlyCompleted).toList();
      if (newlyCompleted.isNotEmpty) {
        final allComplete = nextData.every((q) => q.isCompleted);
        QuestCompletionDialog.show(
          context,
          completedQuests: newlyCompleted,
          allQuestsComplete: allComplete && !bonusClaimed,
        );
      }
    });

    return progressAsync.when(
      data: (progress) => DailyQuestList(
        progress: progress,
        bonusClaimed: bonusClaimed,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
