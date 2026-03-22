import 'package:equatable/equatable.dart';

enum QuestRewardType { xp, coins, cardPack }

class DailyQuest extends Equatable {
  const DailyQuest({
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

class DailyQuestProgress extends Equatable {
  const DailyQuestProgress({
    required this.quest,
    required this.currentValue,
    required this.isCompleted,
    required this.rewardAwarded,
    required this.newlyCompleted,
  });

  final DailyQuest quest;
  final int currentValue;
  final bool isCompleted;
  final bool rewardAwarded;
  final bool newlyCompleted;

  @override
  List<Object?> get props => [quest.id, currentValue, isCompleted, rewardAwarded, newlyCompleted];
}

class DailyBonusResult {
  const DailyBonusResult({required this.success, required this.unopenedPacks});

  final bool success;
  final int unopenedPacks;
}
