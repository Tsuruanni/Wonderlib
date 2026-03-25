/// Types of assignments teachers can create.
enum AssignmentType {
  book,
  vocabulary,
  unit;

  /// Database string representation.
  String get dbValue => name;

  /// Parse from database string.
  static AssignmentType fromDbValue(String value) {
    return AssignmentType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => AssignmentType.book,
    );
  }

  String get displayName {
    switch (this) {
      case AssignmentType.book:
        return 'Book Reading';
      case AssignmentType.vocabulary:
        return 'Vocabulary';
      case AssignmentType.unit:
        return 'Unit';
    }
  }
}
