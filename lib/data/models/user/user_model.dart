import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/user.dart';

/// Model for User entity - handles JSON serialization
class UserModel {
  final String id;
  final String schoolId;
  final String? classId;
  final String role;
  final String? studentNumber;
  final String firstName;
  final String lastName;
  final String? email;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
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
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
    this.settings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      classId: json['class_id'] as String?,
      role: json['role'] as String? ?? 'student',
      studentNumber: json['student_number'] as String?,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'class_id': classId,
      'role': role,
      'student_number': studentNumber,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'avatar_url': avatarUrl,
      'xp': xp,
      'level': level,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date': lastActivityDate?.toIso8601String(),
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
      'settings': settings,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  User toEntity() {
    return User(
      id: id,
      schoolId: schoolId,
      classId: classId,
      role: parseRole(role),
      studentNumber: studentNumber,
      firstName: firstName,
      lastName: lastName,
      email: email,
      avatarUrl: avatarUrl,
      xp: xp,
      level: level,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastActivityDate: lastActivityDate,
      settings: settings,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory UserModel.fromEntity(User entity) {
    return UserModel(
      id: entity.id,
      schoolId: entity.schoolId,
      classId: entity.classId,
      role: roleToString(entity.role),
      studentNumber: entity.studentNumber,
      firstName: entity.firstName,
      lastName: entity.lastName,
      email: entity.email,
      avatarUrl: entity.avatarUrl,
      xp: entity.xp,
      level: entity.level,
      currentStreak: entity.currentStreak,
      longestStreak: entity.longestStreak,
      lastActivityDate: entity.lastActivityDate,
      settings: entity.settings,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
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
