import 'package:equatable/equatable.dart';

import 'daily_quest.dart' show QuestRewardType;

export 'daily_quest.dart' show QuestRewardType;

class MonthlyQuest extends Equatable {
  const MonthlyQuest({
    required this.id,
    required this.questType,
    required this.title,
    required this.icon,
    required this.goalValue,
    required this.rewardType,
    required this.rewardAmount,
  });

  final String id;
  final String questType;
  final String title;
  final String icon;
  final int goalValue;
  final QuestRewardType rewardType;
  final int rewardAmount;

  @override
  List<Object?> get props => [id];
}

class MonthlyQuestProgress extends Equatable {
  const MonthlyQuestProgress({
    required this.quest,
    required this.currentValue,
    required this.isCompleted,
    required this.rewardAwarded,
    required this.newlyCompleted,
    required this.periodKey,
    required this.daysLeft,
    required this.completionCount,
  });

  final MonthlyQuest quest;
  final int currentValue;
  final bool isCompleted;
  final bool rewardAwarded;
  final bool newlyCompleted;
  final String periodKey;
  final int daysLeft;

  /// Total completions of this quest across all months (any period_key).
  /// Drives tier badge progress UI.
  final int completionCount;

  @override
  List<Object?> get props => [
        quest.id,
        currentValue,
        isCompleted,
        rewardAwarded,
        newlyCompleted,
        periodKey,
        daysLeft,
        completionCount,
      ];
}
