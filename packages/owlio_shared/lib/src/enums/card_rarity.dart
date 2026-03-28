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

  /// ARGB hex color for this rarity tier.
  /// Usage: `Color(rarity.colorHex)`
  int get colorHex {
    switch (this) {
      case common:
        return 0xFFAFAFAF;
      case rare:
        return 0xFF1CB0F6;
      case epic:
        return 0xFF9B59B6;
      case legendary:
        return 0xFFFFC800;
    }
  }
}
