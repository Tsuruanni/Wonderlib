import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

class LeagueStatus extends Equatable {
  const LeagueStatus({
    required this.joined,
    required this.thresholdMet,
    required this.currentWeeklyXp,
    this.groupId,
    this.groupMemberCount,
    required this.tier,
    required this.weekStart,
    this.rank,
  });

  final bool joined;
  final bool thresholdMet;
  final int currentWeeklyXp;
  final String? groupId;
  final int? groupMemberCount;
  final LeagueTier tier;
  final DateTime weekStart;
  final int? rank;

  @override
  List<Object?> get props => [
        joined,
        thresholdMet,
        currentWeeklyXp,
        groupId,
        groupMemberCount,
        tier,
        weekStart,
        rank,
      ];
}
