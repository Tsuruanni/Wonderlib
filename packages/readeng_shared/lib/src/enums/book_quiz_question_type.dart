/// Types of questions in book quizzes.
enum BookQuizQuestionType {
  multipleChoice('multiple_choice'),
  fillBlank('fill_blank'),
  eventSequencing('event_sequencing'),
  matching('matching'),
  whoSaysWhat('who_says_what');

  final String dbValue;

  const BookQuizQuestionType(this.dbValue);

  /// Parse from database string (snake_case).
  static BookQuizQuestionType fromDbValue(String value) {
    return BookQuizQuestionType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => BookQuizQuestionType.multipleChoice,
    );
  }
}
