/// Categories for organizing vocabulary word lists.
enum WordListCategory {
  commonWords('common_words', 'Common Words'),
  gradeLevel('grade_level', 'Grade Level'),
  testPrep('test_prep', 'Test Preparation'),
  thematic('thematic', 'Thematic'),
  storyVocab('story_vocab', 'Story Vocabulary');

  final String dbValue;
  final String displayName;

  const WordListCategory(this.dbValue, this.displayName);

  /// Parse from database string (snake_case).
  static WordListCategory fromDbValue(String value) {
    return WordListCategory.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => WordListCategory.commonWords,
    );
  }
}
