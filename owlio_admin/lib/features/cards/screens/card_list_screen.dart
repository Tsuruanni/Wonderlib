import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:owlio_shared/owlio_shared.dart';

import '../../../core/supabase_client.dart';

/// Provider for loading all myth cards
final mythCardsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from(DbTables.mythCards)
      .select()
      .order('card_no');
  return List<Map<String, dynamic>>.from(response);
});

/// Filter by category
final cardCategoryFilterProvider = StateProvider<CardCategory?>((ref) => null);

class CardListScreen extends ConsumerWidget {
  const CardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(mythCardsProvider);
    final categoryFilter = ref.watch(cardCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Myth Cards'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/cards/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Card'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<CardCategory?>(
                    value: categoryFilter,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ...CardCategory.values.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat.label),
                          )),
                    ],
                    onChanged: (value) {
                      ref.read(cardCategoryFilterProvider.notifier).state =
                          value;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (categoryFilter != null)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(cardCategoryFilterProvider.notifier).state =
                          null;
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Card grid
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
                              ? 'No cards in this category'
                              : 'No cards yet',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/cards/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create your first card'),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final card = filtered[index];
                    return _MythCardTile(
                      card: card,
                      onTap: () => context.go('/cards/${card['id']}'),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(mythCardsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MythCardTile extends StatelessWidget {
  const _MythCardTile({required this.card, required this.onTap});

  final Map<String, dynamic> card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardNo = card['card_no'] as String? ?? '';
    final name = card['name'] as String? ?? 'Unknown';
    final category = CardCategory.fromDbValue(card['category'] as String? ?? '');
    final rarity = CardRarity.fromDbValue(card['rarity'] as String? ?? '');
    final power = card['power'] as int? ?? 0;
    final categoryIcon = card['category_icon'] as String? ?? '';
    final isActive = card['is_active'] as bool? ?? true;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _rarityColor(rarity), width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: card_no + rarity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cardNo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  _RarityChip(rarity: rarity),
                ],
              ),
              const Spacer(),
              // Icon
              Center(
                child: Text(
                  categoryIcon.isNotEmpty ? categoryIcon : '🃏',
                  style: const TextStyle(fontSize: 36),
                ),
              ),
              const Spacer(),
              // Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Category + Power
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 12, color: Colors.amber.shade700),
                      Text(
                        '$power',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!isActive) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Inactive',
                    style: TextStyle(fontSize: 9, color: Colors.red.shade700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _rarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey.shade400;
      case CardRarity.rare:
        return Colors.blue.shade400;
      case CardRarity.epic:
        return Colors.purple.shade400;
      case CardRarity.legendary:
        return Colors.amber.shade600;
    }
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity});

  final CardRarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(
          fontSize: 9,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _color {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey.shade600;
      case CardRarity.rare:
        return Colors.blue.shade600;
      case CardRarity.epic:
        return Colors.purple.shade600;
      case CardRarity.legendary:
        return Colors.amber.shade700;
    }
  }
}
