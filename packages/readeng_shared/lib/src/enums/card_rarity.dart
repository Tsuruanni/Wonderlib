/// Card rarity levels - determines drop rate, visual style, and value.
enum CardRarity {
  common,
  rare,
  epic,
  legendary;

  /// Database string representation.
  String get dbValue => name;

  /// Parse from database string.
  static CardRarity fromDbValue(String value) {
    return CardRarity.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => CardRarity.common,
    );
  }

  /// Display label for UI.
  String get label {
    switch (this) {
      case common:
        return 'Common';
      case rare:
        return 'Rare';
      case epic:
        return 'Epic';
      case legendary:
        return 'Legendary';
    }
  }
}
