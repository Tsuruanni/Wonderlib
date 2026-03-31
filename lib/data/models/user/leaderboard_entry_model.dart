import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/leaderboard_entry.dart';

class LeaderboardEntryModel {
  const LeaderboardEntryModel({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.avatarEquippedCache,
    required this.totalXp,
    required this.weeklyXp,
    required this.level,
    required this.rank,
    this.previousRank,
    this.className,
    required this.leagueTier,
    this.totalCount,
    this.schoolName,
    this.isSameSchool = false,
    this.isBot = false,
    this.previousGroupId,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      avatarEquippedCache: json['avatar_equipped_cache'] as Map<String, dynamic>?,
      totalXp: (json['total_xp'] ?? json['xp']) as int? ?? 0,
      weeklyXp: (json['weekly_xp'] as num?)?.toInt() ?? 0,
      level: json['level'] as int? ?? 1,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      previousRank: (json['previous_rank'] as num?)?.toInt(),
      className: json['class_name'] as String?,
      leagueTier: LeagueTier.fromDbValue(
        json['league_tier'] as String? ?? 'bronze',
      ),
      totalCount: (json['total_count'] as num?)?.toInt(),
      schoolName: json['school_name'] as String?,
      isSameSchool: json['is_same_school'] as bool? ?? false,
      isBot: json['is_bot'] as bool? ?? false,
      previousGroupId: json['previous_group_id'] as String?,
    );
  }

  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final Map<String, dynamic>? avatarEquippedCache;
  final int totalXp;
  final int weeklyXp;
  final int level;
  final int rank;
  final int? previousRank;
  final String? className;
  final LeagueTier leagueTier;
  final int? totalCount;
  final String? schoolName;
  final bool isSameSchool;
  final bool isBot;
  final String? previousGroupId;

  LeaderboardEntry toEntity() {
    return LeaderboardEntry(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
      avatarEquippedCache: avatarEquippedCache,
      totalXp: totalXp,
      weeklyXp: weeklyXp,
      level: level,
      rank: rank,
      previousRank: previousRank,
      className: className,
      leagueTier: leagueTier,
      totalCount: totalCount,
      schoolName: schoolName,
      isSameSchool: isSameSchool,
      isBot: isBot,
      previousGroupId: previousGroupId,
    );
  }
}
