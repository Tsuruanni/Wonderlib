import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/league_status.dart';

class LeagueStatusModel {
  const LeagueStatusModel({
    this.groupId,
    this.groupMemberCount,
    required this.tier,
    required this.weekStart,
    this.rank,
    required this.joined,
    required this.thresholdMet,
    required this.currentWeeklyXp,
  });

  factory LeagueStatusModel.fromJson(Map<String, dynamic> json) {
    return LeagueStatusModel(
      groupId: json['group_id'] as String?,
      groupMemberCount: (json['group_member_count'] as num?)?.toInt(),
      tier: LeagueTier.fromDbValue(json['tier'] as String? ?? 'bronze'),
      weekStart: DateTime.parse(json['week_start'] as String),
      rank: (json['rank'] as num?)?.toInt(),
      joined: json['joined'] as bool? ?? false,
      thresholdMet: json['threshold_met'] as bool? ?? false,
      currentWeeklyXp: (json['current_weekly_xp'] as num?)?.toInt() ?? 0,
    );
  }

  final String? groupId;
  final int? groupMemberCount;
  final LeagueTier tier;
  final DateTime weekStart;
  final int? rank;
  final bool joined;
  final bool thresholdMet;
  final int currentWeeklyXp;

  LeagueStatus toEntity() {
    return LeagueStatus(
      groupId: groupId,
      groupMemberCount: groupMemberCount,
      tier: tier,
      weekStart: weekStart,
      rank: rank,
      joined: joined,
      thresholdMet: thresholdMet,
      currentWeeklyXp: currentWeeklyXp,
    );
  }
}
