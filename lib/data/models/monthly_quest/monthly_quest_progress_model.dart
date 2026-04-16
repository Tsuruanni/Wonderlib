import '../../../domain/entities/monthly_quest.dart';

class MonthlyQuestProgressModel {
  const MonthlyQuestProgressModel({
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
    required this.periodKey,
    required this.daysLeft,
    required this.completionCount,
  });

  factory MonthlyQuestProgressModel.fromJson(Map<String, dynamic> json) {
    return MonthlyQuestProgressModel(
      questId: json['quest_id'] as String,
      questType: json['quest_type'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String? ?? '🏆',
      goalValue: json['goal_value'] as int,
      currentValue: json['current_value'] as int,
      isCompleted: json['is_completed'] as bool,
      rewardType: json['reward_type'] as String,
      rewardAmount: json['reward_amount'] as int,
      rewardAwarded: json['reward_awarded'] as bool,
      newlyCompleted: json['newly_completed'] as bool? ?? false,
      periodKey: json['period_key'] as String,
      daysLeft: json['days_left'] as int,
      completionCount: json['completion_count'] as int? ?? 0,
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
  final String periodKey;
  final int daysLeft;
  final int completionCount;

  MonthlyQuestProgress toEntity() {
    return MonthlyQuestProgress(
      quest: MonthlyQuest(
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
      periodKey: periodKey,
      daysLeft: daysLeft,
      completionCount: completionCount,
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
