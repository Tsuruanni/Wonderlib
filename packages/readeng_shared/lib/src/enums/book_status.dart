/// Publication status of a book.
enum BookStatus {
  draft,
  published,
  archived;

  /// Database string representation.
  String get dbValue => name;

  /// Parse from database string.
  static BookStatus fromDbValue(String value) {
    return BookStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => BookStatus.draft,
    );
  }
}
