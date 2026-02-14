/// Common European Framework of Reference (CEFR) language levels.
enum CEFRLevel {
  a1('A1', 'Beginner (A1)'),
  a2('A2', 'Elementary (A2)'),
  b1('B1', 'Intermediate (B1)'),
  b2('B2', 'Upper Intermediate (B2)'),
  c1('C1', 'Advanced (C1)'),
  c2('C2', 'Proficient (C2)');

  final String dbValue;
  final String displayName;

  const CEFRLevel(this.dbValue, this.displayName);

  /// Parse from database string (e.g. 'A1', 'B2').
  static CEFRLevel fromDbValue(String value) {
    return CEFRLevel.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => CEFRLevel.a1,
    );
  }

  /// All CEFR level strings for dropdowns.
  static List<String> get allValues =>
      CEFRLevel.values.map((e) => e.dbValue).toList();
}
