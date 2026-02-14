/// User roles in the ReadEng platform.
enum UserRole {
  student,
  teacher,
  head,
  admin;

  /// Database string representation.
  String get dbValue => name;

  /// Parse from database string.
  static UserRole fromDbValue(String value) {
    return UserRole.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => UserRole.student,
    );
  }

  bool get isStudent => this == student;
  bool get isTeacher => this == teacher;
  bool get isHead => this == head;
  bool get isAdmin => this == admin;
  bool get canManageStudents => this == teacher || this == head || this == admin;
  bool get canManageTeachers => this == head || this == admin;
  bool get canManageContent => this == admin;
}
