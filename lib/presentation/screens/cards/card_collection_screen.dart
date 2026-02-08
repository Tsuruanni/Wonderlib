import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/cards/locked_card_widget.dart';
import '../../widgets/cards/myth_card_widget.dart';
import '../../widgets/common/top_navbar.dart';

class CardCollectionScreen extends ConsumerWidget {
  const CardCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(cardCatalogProvider);
    final userCardsAsync = ref.watch(userCardsProvider);
    final ownedIds = ref.watch(ownedCardIdsProvider);
    
    // We categorize the full catalog to show all sections
    final catalog = catalogAsync.valueOrNull ?? [];
    final userCards = userCardsAsync.valueOrNull ?? [];
    
    // Group all cards by category
    final categorizedCards = <CardCategory, List<MythCard>>{};
    for (final card in catalog) {
      categorizedCards.putIfAbsent(card.category, () => []).add(card);
    }

    // SORTING: Sort each category list
    // 1. Owned first
    // 2. Rarity (Legendary -> Epic -> Rare -> Common)
    // 3. Card Number/ID
    for (final category in categorizedCards.keys) {
      categorizedCards[category]!.sort((a, b) {
        final aOwned = ownedIds.contains(a.id);
        final bOwned = ownedIds.contains(b.id);
        
        // 1. Owned Status
        if (aOwned && !bOwned) return -1;
        if (!aOwned && bOwned) return 1;

        // 2. Rarity Sorting
        if (aOwned && bOwned) {
          // Owned: Descending (Legendary -> Common)
          // index: 0=Common ... 3=Legendary
          // b.index.compareTo(a.index) gives Descending
          final rarityCompare = b.rarity.index.compareTo(a.rarity.index);
          if (rarityCompare != 0) return rarityCompare;
        } else if (!aOwned && !bOwned) {
          // Unowned: Ascending (Common -> Legendary)
          // a.index.compareTo(b.index) gives Ascending
          final rarityCompare = a.rarity.index.compareTo(b.rarity.index);
          if (rarityCompare != 0) return rarityCompare;
        }

        // 3. Card No (Ascending)
        return a.cardNo.compareTo(b.cardNo);
      });
    }

    // Calculate progress map
    final categoryProgress = <CardCategory, int>{};
    for (final uc in userCards) {
      final cat = uc.card.category;
      categoryProgress[cat] = (categoryProgress[cat] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 1. Top Navbar (with Coins, no Streak)
          const SafeArea(
            bottom: false,
            child: TopNavbar(),
          ),

          // 2. Scrollable Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF5F7FA), Color(0xFFE4E7EB)],
                ),
              ),
              child: catalogAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (_) {
                  return CustomScrollView(
                    slivers: [
                      // Open Pack Banner
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: _OpenPackBanner(
                            onTap: () => context.push('/cards/open-pack'),
                          ),
                        ),
                      ),

                      // Categorized Sections (Netflix Style)
                      ...CardCategory.values.map((category) {
                        final cards = categorizedCards[category] ?? [];
                        if (cards.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                        
                        final ownedCount = categoryProgress[category] ?? 0;
                        
                        return SliverToBoxAdapter(
                          child: _CategorySection(
                            category: category,
                            cards: cards,
                            ownedCount: ownedCount,
                            ownedIds: ownedIds,
                            userCards: userCards,
                            onCardTap: (card, quantity) => _showCardDetail(context, card, quantity),
                            onLockedTap: (card) => _showLockedCardInfo(context, card),
                          ),
                        );
                      }),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCardDetail(BuildContext context, MythCard card, int quantity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
             Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.neutral,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SizedBox(
                      height: 400,
                      child: MythCardWidget(
                        card: card,
                        isFull: true,
                        quantity: quantity,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Card Details
                    Text(
                      card.name,
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CardColors.getRarityColor(card.rarity).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: CardColors.getRarityColor(card.rarity),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${card.rarity.label.toUpperCase()} CARD',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: CardColors.getRarityColor(card.rarity),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _DetailStatItem(
                          label: 'POWER',
                          value: '${card.power}',
                          icon: Icons.bolt_rounded,
                          color: AppColors.wasp,
                        ),
                         _DetailStatItem(
                          label: 'COPIES',
                          value: '$quantity',
                          icon: Icons.copy_rounded,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (card.description != null) ...[
                      Text(
                        'LORE',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.neutralText,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.description!,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          color: AppColors.black,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLockedCardInfo(BuildContext context, MythCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.neutral,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.lock_rounded, size: 48, color: AppColors.neutral),
            const SizedBox(height: 16),
            Text(
              'Locked Card',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This card is part of the\n${card.category.label} collection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/cards/open-pack');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'OPEN PACKS',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.cards,
    required this.ownedCount,
    required this.ownedIds,
    required this.userCards,
    required this.onCardTap,
    required this.onLockedTap,
  });

  final CardCategory category;
  final List<MythCard> cards;
  final int ownedCount;
  final Set<String> ownedIds;
  final List<UserCard> userCards;
  final Function(MythCard, int) onCardTap;
  final Function(MythCard) onLockedTap;

  @override
  Widget build(BuildContext context) {
    final progress = cards.isEmpty ? 0.0 : ownedCount / cards.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                category.icon,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.label,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neutral.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$ownedCount / ${cards.length}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralText,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Progress Bar Line
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.neutral.withValues(alpha: 0.3),
              color: CardColors.getCategoryColor(category),
              minHeight: 4,
            ),
          ),
        ),
        
        const SizedBox(height: 12),

        // Horizontal List
        SizedBox(
          height: 220, // Height to accommodate aspect ratio
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final card = cards[index];
              final isOwned = ownedIds.contains(card.id);

              return SizedBox(
                width: 140, // 220 height * 0.7 aspect ratio ~= 154
                child: isOwned
                  ? (() {
                      final userCard = userCards.firstWhere((uc) => uc.cardId == card.id);
                      return MythCardWidget(
                        card: card,
                        quantity: userCard.quantity,
                        onTap: () => onCardTap(card, userCard.quantity),
                      );
                    })()
                  : LockedCardWidget(
                      card: card,
                      onTap: () => onLockedTap(card),
                    ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _OpenPackBanner extends StatelessWidget {
  const _OpenPackBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF6B4CFE), Color(0xFFD355FF)], // Epic purple/pink gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B4CFE).withValues(alpha: 0.4),
              offset: const Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background patterns or shapes could go here
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.style_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GET NEW CARDS',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Open Booster Pack',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Cost Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: AppColors.wasp,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '100',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStatItem extends StatelessWidget {
  const _DetailStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
