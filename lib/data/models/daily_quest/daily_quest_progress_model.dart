import '../../../domain/entities/daily_quest.dart';

class DailyQuestProgressModel {
  const DailyQuestProgressModel({
    required this.questId,
    required this.questType,
    required this.title,
    required this.icon,
    required this.goalValue,
    required this.currentValue,
    required this.isCompleted,
    required this.rewardType,
    required this.rewardAmount,
    required this.rewardAwarded,
    required this.newlyCompleted,
  });

  factory DailyQuestProgressModel.fromJson(Map<String, dynamic> json) {
    return DailyQuestProgressModel(
      questId: json['quest_id'] as String,
      questType: json['quest_type'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String? ?? '🎯',
      goalValue: json['goal_value'] as int,
      currentValue: json['current_value'] as int,
      isCompleted: json['is_completed'] as bool,
      rewardType: json['reward_type'] as String,
      rewardAmount: json['reward_amount'] as int,
      rewardAwarded: json['reward_awarded'] as bool,
      newlyCompleted: json['newly_completed'] as bool? ?? false,
    );
  }

  final String questId;
  final String questType;
  final String title;
  final String icon;
  final int goalValue;
  final int currentValue;
  final bool isCompleted;
  final String rewardType;
  final int rewardAmount;
  final bool rewardAwarded;
  final bool newlyCompleted;

  DailyQuestProgress toEntity() {
    return DailyQuestProgress(
      quest: DailyQuest(
        id: questId,
        questType: questType,
        title: title,
        icon: icon,
        goalValue: goalValue,
        rewardType: _parseRewardType(rewardType),
        rewardAmount: rewardAmount,
      ),
      currentValue: currentValue,
      isCompleted: isCompleted,
      rewardAwarded: rewardAwarded,
      newlyCompleted: newlyCompleted,
    );
  }

  static QuestRewardType _parseRewardType(String type) {
    switch (type) {
      case 'card_pack':
        return QuestRewardType.cardPack;
      case 'coins':
      default:
        return QuestRewardType.coins;
    }
  }
}
