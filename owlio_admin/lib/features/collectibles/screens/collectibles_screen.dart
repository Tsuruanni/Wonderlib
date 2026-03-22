import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../badges/screens/badge_list_screen.dart';
import '../../cards/screens/card_list_screen.dart';

/// Combined screen for Badges + Myth Cards with tabs.
class CollectiblesScreen extends ConsumerStatefulWidget {
  const CollectiblesScreen({super.key, this.initialTab = 0});

  /// 0 = Rozetler, 1 = Mitoloji Kartları
  final int initialTab;

  @override
  ConsumerState<CollectiblesScreen> createState() => _CollectiblesScreenState();
}

class _CollectiblesScreenState extends ConsumerState<CollectiblesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koleksiyon'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: _buildActions(context),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Rozetler'),
            Tab(text: 'Mitoloji Kartları'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BadgesTab(),
          _MythCardsTab(),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (_tabController.index == 0) {
      return [
        FilledButton.icon(
          onPressed: () => context.go('/badges/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Yeni Rozet'),
        ),
        const SizedBox(width: 16),
      ];
    } else {
      return [
        FilledButton.icon(
          onPressed: () => context.go('/cards/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Yeni Kart'),
        ),
        const SizedBox(width: 16),
      ];
    }
  }
}

// ============================================
// BADGES TAB
// ============================================

class _BadgesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);

    return badgesAsync.when(
      data: (badges) {
        if (badges.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Henüz rozet yok',
                    style:
                        TextStyle(fontSize: 18, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            final badge = badges[index];
            return _CompactBadgeCard(
              badge: badge,
              onTap: () => context.go('/badges/${badge['id']}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Hata: $error')),
    );
  }
}

class _CompactBadgeCard extends StatelessWidget {
  const _CompactBadgeCard({required this.badge, required this.onTap});

  final Map<String, dynamic> badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = badge['icon'] as String? ?? '🏆';
    final name = badge['name'] as String? ?? '';
    final conditionType = badge['condition_type'] as String? ?? '';
    final conditionValue = badge['condition_value'] as int? ?? 0;
    final xpReward = badge['xp_reward'] as int? ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _MiniChip(
                    label: _conditionLabel(conditionType, conditionValue),
                    color: Colors.blue,
                  ),
                  _MiniChip(label: '+$xpReward XP', color: Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _conditionLabel(String type, int value) {
    return switch (type) {
      'xp_total' => '$value XP',
      'streak_days' => '$value gün',
      'books_completed' => '$value kitap',
      'vocabulary_learned' => '$value kelime',
      'perfect_scores' => '$value tam puan',
      _ => type,
    };
  }
}

// ============================================
// MYTH CARDS TAB
// ============================================

class _MythCardsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(mythCardsProvider);
    final categoryFilter = ref.watch(cardCategoryFilterProvider);

    return Column(
      children: [
        // Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<CardCategory?>(
                  value: categoryFilter,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Tüm Kategoriler')),
                    ...CardCategory.values.map((cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat.label))),
                  ],
                  onChanged: (value) => ref
                      .read(cardCategoryFilterProvider.notifier)
                      .state = value,
                ),
              ),
              if (categoryFilter != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => ref
                      .read(cardCategoryFilterProvider.notifier)
                      .state = null,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Temizle'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: cardsAsync.when(
            data: (cards) {
              final filtered = categoryFilter != null
                  ? cards
                      .where(
                          (c) => c['category'] == categoryFilter.dbValue)
                      .toList()
                  : cards;

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.style_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        categoryFilter != null
                            ? 'Bu kategoride kart yok'
                            : 'Henüz kart yok',
                        style: TextStyle(
                            fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final card = filtered[index];
                  return _CompactMythCard(
                    card: card,
                    onTap: () => context.go('/cards/${card['id']}'),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Hata: $error')),
          ),
        ),
      ],
    );
  }
}

class _CompactMythCard extends StatelessWidget {
  const _CompactMythCard({required this.card, required this.onTap});

  final Map<String, dynamic> card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardNo = card['card_no'] as String? ?? '';
    final name = card['name'] as String? ?? '';
    final rarity = CardRarity.fromDbValue(card['rarity'] as String? ?? '');
    final power = card['power'] as int? ?? 0;
    final imageUrl = card['image_url'] as String?;
    final categoryIcon = card['category_icon'] as String? ?? '🃏';
    final isActive = card['is_active'] as bool? ?? true;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _rarityColor(rarity), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image or emoji fallback
            Expanded(
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(categoryIcon,
                            style: const TextStyle(fontSize: 28)),
                      ),
                    )
                  : Center(
                      child: Text(categoryIcon,
                          style: const TextStyle(fontSize: 28)),
                    ),
            ),
            // Info bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: Colors.black.withValues(alpha: 0.03),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              _rarityColor(rarity).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(rarity.label,
                            style: TextStyle(
                                fontSize: 7,
                                color: _rarityColor(rarity),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(cardNo,
                          style: TextStyle(
                              fontSize: 8, color: Colors.grey.shade500)),
                      const Spacer(),
                      Icon(Icons.bolt,
                          size: 9, color: Colors.amber.shade700),
                      Text('$power',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700)),
                      if (!isActive) ...[
                        const SizedBox(width: 4),
                        Text('Pasif',
                            style: TextStyle(
                                fontSize: 7,
                                color: Colors.red.shade600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _rarityColor(CardRarity rarity) {
    return switch (rarity) {
      CardRarity.common => Colors.grey.shade400,
      CardRarity.rare => Colors.blue.shade400,
      CardRarity.epic => Colors.purple.shade400,
      CardRarity.legendary => Colors.amber.shade600,
    };
  }
}

// ============================================
// SHARED
// ============================================

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
