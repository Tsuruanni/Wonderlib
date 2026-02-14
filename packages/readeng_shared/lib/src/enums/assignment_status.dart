/// Status of a student's assignment progress.
enum AssignmentStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  overdue('overdue');

  final String dbValue;

  const AssignmentStatus(this.dbValue);

  /// Parse from database string (snake_case).
  static AssignmentStatus fromDbValue(String value) {
    return AssignmentStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => AssignmentStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.overdue:
        return 'Overdue';
    }
  }
}
