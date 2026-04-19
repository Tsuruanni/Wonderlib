import 'package:flutter/material.dart';

/// Single source of truth for admin sidebar branches.
///
/// List order = branch index in StatefulShellRoute. Router reads this to
/// build branches; sidebar reads this to render items. Keeping both in sync
/// is a hard requirement — never edit one without the other.
class AdminNavEntry {
  const AdminNavEntry({
    required this.rootPath,
    required this.icon,
    required this.label,
    required this.group,
  });

  final String rootPath;
  final IconData icon;
  final String label;
  final String group;
}

/// Special group label for items that render standalone (no group header).
const String kStandaloneGroup = '';

/// Branch index = position in this list. Order matters.
const List<AdminNavEntry> kAdminNavEntries = [
  // 0 — standalone
  AdminNavEntry(
    rootPath: '/',
    icon: Icons.dashboard_outlined,
    label: 'Genel Bakış',
    group: kStandaloneGroup,
  ),
  // İÇERİK
  AdminNavEntry(
    rootPath: '/books',
    icon: Icons.menu_book,
    label: 'Kitaplar',
    group: 'İÇERİK',
  ),
  AdminNavEntry(
    rootPath: '/vocabulary',
    icon: Icons.abc,
    label: 'Kelime Havuzu',
    group: 'İÇERİK',
  ),
  AdminNavEntry(
    rootPath: '/units',
    icon: Icons.grid_view_rounded,
    label: 'Üniteler',
    group: 'İÇERİK',
  ),
  // KULLANICILAR
  AdminNavEntry(
    rootPath: '/schools',
    icon: Icons.school,
    label: 'Okullar',
    group: 'KULLANICILAR',
  ),
  AdminNavEntry(
    rootPath: '/classes',
    icon: Icons.class_,
    label: 'Sınıflar',
    group: 'KULLANICILAR',
  ),
  AdminNavEntry(
    rootPath: '/users',
    icon: Icons.people,
    label: 'Kullanıcılar',
    group: 'KULLANICILAR',
  ),
  AdminNavEntry(
    rootPath: '/recent-activity',
    icon: Icons.timeline,
    label: 'Son Etkinlikler',
    group: 'KULLANICILAR',
  ),
  // ÖĞRENME
  AdminNavEntry(
    rootPath: '/learning-paths',
    icon: Icons.route,
    label: 'Öğrenme Yolları',
    group: 'ÖĞRENME',
  ),
  // OYUNLAŞTIRMA
  AdminNavEntry(
    rootPath: '/collectibles',
    icon: Icons.emoji_events,
    label: 'Koleksiyon',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/quests',
    icon: Icons.bolt,
    label: 'Günlük Görevler',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/treasure-wheel',
    icon: Icons.casino,
    label: 'Hazine Çarkı',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/avatars',
    icon: Icons.face,
    label: 'Avatar Yönetimi',
    group: 'OYUNLAŞTIRMA',
  ),
  AdminNavEntry(
    rootPath: '/tiles',
    icon: Icons.map,
    label: 'Tile Temaları',
    group: 'OYUNLAŞTIRMA',
  ),
  // SİSTEM
  AdminNavEntry(
    rootPath: '/notifications',
    icon: Icons.notifications_active,
    label: 'Bildirimler',
    group: 'SİSTEM',
  ),
  AdminNavEntry(
    rootPath: '/settings',
    icon: Icons.settings,
    label: 'Ayarlar',
    group: 'SİSTEM',
  ),
];
