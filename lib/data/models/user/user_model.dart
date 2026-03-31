import 'package:owlio_shared/owlio_shared.dart';

import '../../../domain/entities/user.dart';

/// Model for User entity - handles JSON serialization
class UserModel {

  const UserModel({
    required this.id,
    required this.schoolId,
    this.classId,
    required this.role,
    this.studentNumber,
    this.username,
    required this.firstName,
    required this.lastName,
    this.email,
    this.avatarUrl,
    this.avatarBaseId,
    this.avatarEquippedCache,
    this.xp = 0,
    this.coins = 0,
    this.unopenedPacks = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.streakFreezeCount = 0,
    this.lastActivityDate,
    this.settings = const {},
    this.leagueTier = LeagueTier.bronze,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      classId: json['class_id'] as String?,
      role: parseRole(json['role'] as String? ?? 'student'),
      studentNumber: json['student_number'] as String?,
      username: json['username'] as String?,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarBaseId: json['avatar_base_id'] as String?,
      avatarEquippedCache: json['avatar_equipped_cache'] as Map<String, dynamic>?,
      xp: json['xp'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      unopenedPacks: json['unopened_packs'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      streakFreezeCount: json['streak_freeze_count'] as int? ?? 0,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      leagueTier: LeagueTier.fromDbValue(json['league_tier'] as String? ?? 'bronze'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
          (json['updated_at'] ?? json['created_at']) as String),
    );
  }

  factory UserModel.fromEntity(User entity) {
    return UserModel(
      id: entity.id,
      schoolId: entity.schoolId,
      classId: entity.classId,
      role: entity.role,
      studentNumber: entity.studentNumber,
      username: entity.username,
      firstName: entity.firstName,
      lastName: entity.lastName,
      email: entity.email,
      avatarUrl: entity.avatarUrl,
      avatarBaseId: entity.avatarBaseId,
      avatarEquippedCache: entity.avatarEquippedCache,
      xp: entity.xp,
      coins: entity.coins,
      unopenedPacks: entity.unopenedPacks,
      level: entity.level,
      currentStreak: entity.currentStreak,
      longestStreak: entity.longestStreak,
      streakFreezeCount: entity.streakFreezeCount,
      lastActivityDate: entity.lastActivityDate,
      settings: entity.settings,
      leagueTier: entity.leagueTier,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
  final String id;
  final String schoolId;
  final String? classId;
  final UserRole role;
  final String? studentNumber;
  final String? username;
  final String firstName;
  final String lastName;
  final String? email;
  final String? avatarUrl;
  final String? avatarBaseId;
  final Map<String, dynamic>? avatarEquippedCache;
  final int xp;
  final int coins;
  final int unopenedPacks;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final int streakFreezeCount;
  final DateTime? lastActivityDate;
  final Map<String, dynamic> settings;
  final LeagueTier leagueTier;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'class_id': classId,
      'role': role.name,
      'student_number': studentNumber,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'avatar_url': avatarUrl,
      'avatar_base_id': avatarBaseId,
      'avatar_equipped_cache': avatarEquippedCache,
      'xp': xp,
      'coins': coins,
      'unopened_packs': unopenedPacks,
      'level': level,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'streak_freeze_count': streakFreezeCount,
      'last_activity_date': lastActivityDate?.toIso8601String(),
      'settings': settings,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'settings': settings,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  User toEntity() {
    return User(
      id: id,
      schoolId: schoolId,
      classId: classId,
      role: role,
      studentNumber: studentNumber,
      username: username,
      firstName: firstName,
      lastName: lastName,
      email: email,
      avatarUrl: avatarUrl,
      avatarBaseId: avatarBaseId,
      avatarEquippedCache: avatarEquippedCache,
      xp: xp,
      coins: coins,
      unopenedPacks: unopenedPacks,
      level: level,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      streakFreezeCount: streakFreezeCount,
      lastActivityDate: lastActivityDate,
      settings: settings,
      leagueTier: leagueTier,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static UserRole parseRole(String role) {
    switch (role) {
      case 'teacher':
        return UserRole.teacher;
      case 'head':
        return UserRole.head;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'student';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.head:
        return 'head';
      case UserRole.admin:
        return 'admin';
    }
  }
}
