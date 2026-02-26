import 'package:equatable/equatable.dart';
import 'package:owlio_shared/owlio_shared.dart';

class User extends Equatable {

  const User({
    required this.id,
    required this.schoolId,
    this.classId,
    required this.role,
    this.studentNumber,
    required this.firstName,
    required this.lastName,
    this.email,
    this.avatarUrl,
    this.xp = 0,
    this.coins = 0,
    this.unopenedPacks = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    this.settings = const {},
    this.leagueTier = LeagueTier.bronze,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String schoolId;
  final String? classId;
  final UserRole role;
  final String? studentNumber;
  final String firstName;
  final String lastName;
  final String? email;
  final String? avatarUrl;
  final int xp;
  final int coins;
  final int unopenedPacks;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final Map<String, dynamic> settings;
  final LeagueTier leagueTier;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  bool get hasActiveStreak => currentStreak > 0;

  User copyWith({
    String? id,
    String? schoolId,
    String? classId,
    UserRole? role,
    String? studentNumber,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarUrl,
    int? xp,
    int? coins,
    int? unopenedPacks,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityDate,
    Map<String, dynamic>? settings,
    LeagueTier? leagueTier,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      classId: classId ?? this.classId,
      role: role ?? this.role,
      studentNumber: studentNumber ?? this.studentNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      unopenedPacks: unopenedPacks ?? this.unopenedPacks,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      settings: settings ?? this.settings,
      leagueTier: leagueTier ?? this.leagueTier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        schoolId,
        classId,
        role,
        studentNumber,
        firstName,
        lastName,
        email,
        avatarUrl,
        xp,
        coins,
        unopenedPacks,
        level,
        currentStreak,
        longestStreak,
        lastActivityDate,
        settings,
        leagueTier,
        createdAt,
        updatedAt,
      ];
}
