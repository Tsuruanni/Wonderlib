import 'package:owlio_shared/owlio_shared.dart';
import '../../../domain/repositories/teacher_repository.dart';

/// Model for StudentSummary - handles JSON serialization
class StudentSummaryModel {

  const StudentSummaryModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.studentNumber,
    this.username,
    this.email,
    this.avatarUrl,
    this.avatarEquippedCache,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.booksRead,
    required this.avgProgress,
    required this.leagueTier,
    this.wordbankSize = 0,
    this.lastActivityDate,
    this.passwordPlain,
  });

  factory StudentSummaryModel.fromJson(Map<String, dynamic> json) {
    final cache = json['avatar_equipped_cache'];
    final lastAct = json['last_activity_date'] as String?;
    return StudentSummaryModel(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      studentNumber: json['student_number'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarEquippedCache:
          cache is Map<String, dynamic> ? cache : (cache is Map ? Map<String, dynamic>.from(cache) : null),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      currentStreak: (json['streak'] as num?)?.toInt() ?? 0,
      booksRead: (json['books_read'] as num?)?.toInt() ?? 0,
      avgProgress: (json['avg_progress'] as num?)?.toDouble() ?? 0,
      leagueTier: _parseLeagueTier(json['league_tier'] as String?),
      wordbankSize: (json['wordbank_size'] as num?)?.toInt() ?? 0,
      lastActivityDate: lastAct != null ? DateTime.tryParse(lastAct) : null,
      passwordPlain: json['password_plain'] as String?,
    );
  }

  static LeagueTier _parseLeagueTier(String? value) {
    if (value == null || value.isEmpty) return LeagueTier.bronze;
    return LeagueTier.fromDbValue(value);
  }

  final String id;
  final String firstName;
  final String lastName;
  final String? studentNumber;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final Map<String, dynamic>? avatarEquippedCache;
  final int xp;
  final int level;
  final int currentStreak;
  final int booksRead;
  final double avgProgress;
  final LeagueTier leagueTier;
  final int wordbankSize;
  final DateTime? lastActivityDate;
  final String? passwordPlain;

  StudentSummary toEntity() {
    return StudentSummary(
      id: id,
      firstName: firstName,
      lastName: lastName,
      studentNumber: studentNumber,
      username: username,
      email: email,
      avatarUrl: avatarUrl,
      avatarEquippedCache: avatarEquippedCache,
      xp: xp,
      level: level,
      currentStreak: currentStreak,
      booksRead: booksRead,
      avgProgress: avgProgress,
      leagueTier: leagueTier,
      wordbankSize: wordbankSize,
      lastActivityDate: lastActivityDate,
      passwordPlain: passwordPlain,
    );
  }
}
