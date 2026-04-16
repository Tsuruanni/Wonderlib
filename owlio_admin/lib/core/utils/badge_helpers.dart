// Shared badge condition helpers for admin panel.
// Covers all 9 condition types.

/// Short label for badge cards.
/// For param-based types, the second argument can optionally pass the param
/// to produce a richer label (e.g. "Gold lig").
String getConditionLabel(String type, int value, [String? param]) {
  return switch (type) {
    'xp_total' => '$value XP',
    'streak_days' => '$value gün',
    'books_completed' => '$value kitap',
    'vocabulary_learned' => '$value kelime',
    'level_completed' => '$value seviye',
    'cards_collected' => '$value kart',
    'myth_category_completed' =>
        param != null ? '$param: $value kart' : '$value kart (kategori)',
    'league_tier_reached' =>
        param != null ? '$param lig' : 'lig yükselişi',
    _ => '$type: $value',
  };
}

/// Descriptive helper text for the edit form.
String getConditionHelper(String type) {
  return switch (type) {
    'xp_total' => 'Kullanıcının kazanması gereken toplam XP',
    'streak_days' => 'Ardışık aktif gün sayısı',
    'books_completed' => 'Tamamlanması gereken kitap sayısı',
    'vocabulary_learned' => 'Öğrenilmesi gereken kelime sayısı',
    'level_completed' => 'Ulaşılması gereken seviye',
    'cards_collected' => 'Toplanması gereken farklı kart sayısı',
    'myth_category_completed' =>
        'Seçili kategoriden toplanması gereken kart sayısı',
    'league_tier_reached' => 'Ulaşılması gereken lig (placeholder değer: 1)',
    _ => '',
  };
}

/// Dropdown options for myth category param (keys must match DB CHECK constraint on myth_cards.category).
const Map<String, String> mythCategoryOptions = {
  'turkish_myths': 'Türk Mitleri',
  'ancient_greece': 'Antik Yunan',
  'viking_ice_lands': 'Viking & Buz Diyarları',
  'egyptian_deserts': 'Mısır Çölleri',
  'far_east': 'Uzak Doğu',
  'medieval_magic': 'Ortaçağ Büyüsü',
  'legendary_weapons': 'Efsanevi Silahlar',
  'dark_creatures': 'Karanlık Yaratıklar',
};

/// Dropdown options for league tier param (keys must match profiles.league_tier values).
const Map<String, String> leagueTierOptions = {
  'silver': 'Silver',
  'gold': 'Gold',
  'platinum': 'Platinum',
  'diamond': 'Diamond',
};
