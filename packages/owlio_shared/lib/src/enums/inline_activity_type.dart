/// Types of inline microlearning activities within chapters.
enum InlineActivityType {
  trueFalse('true_false'),
  wordTranslation('word_translation'),
  findWords('find_words'),
  matching('matching');

  final String dbValue;

  const InlineActivityType(this.dbValue);

  /// Parse from database string (snake_case).
  static InlineActivityType fromDbValue(String value) {
    return InlineActivityType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => InlineActivityType.trueFalse,
    );
  }
}
