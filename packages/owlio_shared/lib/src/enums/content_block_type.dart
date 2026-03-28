/// Types of content blocks within a chapter.
enum ContentBlockType {
  text,
  image,
  activity;

  /// Database string representation.
  String get dbValue => name;

  /// Parse from database string.
  static ContentBlockType fromDbValue(String value) {
    return ContentBlockType.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => ContentBlockType.text,
    );
  }
}
