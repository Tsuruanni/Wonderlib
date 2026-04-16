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

/// Turkish display label for a badge grouping key (condition_type or
/// 'myth_category_completed:<slug>'). Used by BadgeListScreen and CollectiblesScreen
/// to render section headers in the same way.
String getBadgeGroupHeaderLabel(String key) {
  switch (key) {
    case 'xp_total':
      return 'TOPLAM XP';
    case 'streak_days':
      return 'STREAK';
    case 'books_completed':
      return 'KİTAPLAR';
    case 'vocabulary_learned':
      return 'KELİMELER';
    case 'level_completed':
      return 'SEVİYE';
    case 'league_tier_reached':
      return 'LİG';
    case 'cards_collected':
      return 'KART KOLEKSİYONU';
    case 'myth_category_completed:turkish_myths':
      return 'TÜRK MİTLERİ';
    case 'myth_category_completed:ancient_greece':
      return 'ANTİK YUNAN';
    case 'myth_category_completed:viking_ice_lands':
      return 'VİKİNG & BUZ DİYARLARI';
    case 'myth_category_completed:egyptian_deserts':
      return 'MISIR ÇÖLLERİ';
    case 'myth_category_completed:far_east':
      return 'UZAK DOĞU';
    case 'myth_category_completed:medieval_magic':
      return 'ORTAÇAĞ BÜYÜSÜ';
    case 'myth_category_completed:legendary_weapons':
      return 'EFSANEVİ SİLAHLAR';
    case 'myth_category_completed:dark_creatures':
      return 'KARANLIK YARATIKLAR';
    default:
      return key.toUpperCase();
  }
}

/// Stable display order for badge groups. Used to keep the section sequence
/// identical across screens.
const List<String> badgeGroupOrderedKeys = <String>[
  'xp_total',
  'streak_days',
  'books_completed',
  'vocabulary_learned',
  'level_completed',
  'league_tier_reached',
  'cards_collected',
  'myth_category_completed:turkish_myths',
  'myth_category_completed:ancient_greece',
  'myth_category_completed:viking_ice_lands',
  'myth_category_completed:egyptian_deserts',
  'myth_category_completed:far_east',
  'myth_category_completed:medieval_magic',
  'myth_category_completed:legendary_weapons',
  'myth_category_completed:dark_creatures',
];
