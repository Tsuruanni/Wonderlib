enum LearningPathItemType {
  wordList('word_list', 'Word List'),
  book('book', 'Book');

  final String dbValue;
  final String displayName;

  const LearningPathItemType(this.dbValue, this.displayName);

  static LearningPathItemType fromDbValue(String value) {
    return LearningPathItemType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => LearningPathItemType.wordList,
    );
  }
}
