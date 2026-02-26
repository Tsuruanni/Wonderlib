/// Mythology card categories - 8 total, 12 cards each.
enum CardCategory {
  turkishMyths('turkish_myths', 'Turkish Myths'),
  ancientGreece('ancient_greece', 'Ancient Greece'),
  vikingIceLands('viking_ice_lands', 'Viking Ice Lands'),
  egyptianDeserts('egyptian_deserts', 'Egyptian Deserts'),
  farEast('far_east', 'Far East'),
  medievalMagic('medieval_magic', 'Medieval Magic'),
  legendaryWeapons('legendary_weapons', 'Legendary Weapons'),
  darkCreatures('dark_creatures', 'Dark Creatures');

  final String dbValue;
  final String label;

  const CardCategory(this.dbValue, this.label);

  /// Parse from database string (snake_case).
  static CardCategory fromDbValue(String value) {
    return CardCategory.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => CardCategory.turkishMyths,
    );
  }
}
