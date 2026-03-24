// Shared badge condition helpers for admin panel.
// Covers all 6 condition types: xp_total, streak_days, books_completed,
// vocabulary_learned, perfect_scores, level_completed.

/// Short label for badge cards (e.g., "7 gün", "500 XP").
String getConditionLabel(String type, int value) {
  return switch (type) {
    'xp_total' => '$value XP',
    'streak_days' => '$value gün',
    'books_completed' => '$value kitap',
    'vocabulary_learned' => '$value kelime',
    'perfect_scores' => '$value tam puan',
    'level_completed' => '$value seviye',
    _ => '$type: $value',
  };
}

/// Descriptive helper text for the edit form (e.g., "Ardışık aktif gün sayısı").
String getConditionHelper(String type) {
  return switch (type) {
    'xp_total' => 'Kullanıcının kazanması gereken toplam XP',
    'streak_days' => 'Ardışık aktif gün sayısı',
    'books_completed' => 'Tamamlanması gereken kitap sayısı',
    'vocabulary_learned' => 'Öğrenilmesi gereken kelime sayısı',
    'perfect_scores' => 'Etkinliklerde tam puan sayısı',
    'level_completed' => 'Ulaşılması gereken seviye',
    _ => '',
  };
}
