import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/utils/badge_helpers.dart';
import '../../badges/screens/badge_list_screen.dart';
import '../../cards/providers/card_providers.dart';

/// Renders either the badges list or the myth cards list based on [initialTab].
/// The parameter name is legacy — there are no more internal tabs; it simply
/// selects which content to show. Routed via `/badges` (0) and `/cards` (1).
class CollectiblesScreen extends ConsumerWidget {
  const CollectiblesScreen({super.key, this.initialTab = 0});

  /// 0 = Rozetler, 1 = Mitoloji Kartları
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBadges = initialTab == 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(isBadges ? 'Rozetler' : 'Mitoloji Kartları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go(isBadges ? '/badges/new' : '/cards/new'),
            icon: const Icon(Icons.add, size: 18),
            label: Text(isBadges ? 'Yeni Rozet' : 'Yeni Kart'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isBadges ? _BadgesTab() : _MythCardsTab(),
    );
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

        // Group by condition_type. For myth_category_completed, sub-group by condition_param.
        final groups = <String, List<Map<String, dynamic>>>{};
        for (final b in badges) {
          final type = b['condition_type'] as String? ?? '';
          final param = b['condition_param'] as String?;
          final key = type == 'myth_category_completed' && param != null
              ? 'myth_category_completed:$param'
              : type;
          (groups[key] ??= []).add(b);
        }

        // Stable display order from shared helper.
        final sortedKeys = <String>[];
        for (final k in badgeGroupOrderedKeys) {
          if (groups.containsKey(k)) sortedKeys.add(k);
        }
        for (final k in groups.keys) {
          if (!sortedKeys.contains(k)) sortedKeys.add(k);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final key in sortedKeys) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    getBadgeGroupHeaderLabel(key),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final badge in groups[key]!)
                      SizedBox(
                        width: 200,
                        height: 100,
                        child: _CompactBadgeCard(
                          badge: badge,
                          onTap: () => context.go('/badges/${badge['id']}'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
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
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: icon.startsWith('assets/')
                          ? Image.asset(
                              icon,
                              width: 26,
                              height: 26,
                              fit: BoxFit.contain,
                            )
                          : Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
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
                    label: getConditionLabel(conditionType, conditionValue),
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
