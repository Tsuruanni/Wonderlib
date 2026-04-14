/// Types of conditions that can trigger badge awards.
enum BadgeConditionType {
  xpTotal('xp_total'),
  streakDays('streak_days'),
  booksCompleted('books_completed'),
  vocabularyLearned('vocabulary_learned'),
  perfectScores('perfect_scores'),
  levelCompleted('level_completed'),
  cardsCollected('cards_collected'),
  mythCategoryCompleted('myth_category_completed'),
  leagueTierReached('league_tier_reached');

  final String dbValue;

  const BadgeConditionType(this.dbValue);

  /// Parse from database string (snake_case).
  static BadgeConditionType fromDbValue(String value) {
    return BadgeConditionType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => BadgeConditionType.xpTotal,
    );
  }

  /// True if this condition type requires a `condition_param` string
  /// (category slug, tier name, etc.) in addition to `condition_value`.
  bool get requiresParam => switch (this) {
        BadgeConditionType.mythCategoryCompleted => true,
        BadgeConditionType.leagueTierReached => true,
        _ => false,
      };
}
