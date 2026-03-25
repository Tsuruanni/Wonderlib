/// Types of conditions that can trigger badge awards.
enum BadgeConditionType {
  xpTotal('xp_total'),
  streakDays('streak_days'),
  booksCompleted('books_completed'),
  vocabularyLearned('vocabulary_learned'),
  perfectScores('perfect_scores'),
  levelCompleted('level_completed');

  final String dbValue;

  const BadgeConditionType(this.dbValue);

  /// Parse from database string (snake_case).
  static BadgeConditionType fromDbValue(String value) {
    return BadgeConditionType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => BadgeConditionType.xpTotal,
    );
  }
}
