import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/cards/locked_card_widget.dart';
import '../../widgets/cards/myth_card_widget.dart';
import '../../providers/card_trade_provider.dart';
import '../../widgets/cards/trade_button_card.dart';
import '../../widgets/common/top_navbar.dart';

/// Tracks which card categories are expanded (web only).
final expandedCardCategoriesProvider = StateProvider<Set<CardCategory>>((ref) => {});

class CardCollectionScreen extends ConsumerWidget {
  const CardCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(cardCatalogProvider);
    final ownedIds = ref.watch(ownedCardIdsProvider);
    final categorizedCards = ref.watch(sortedCollectionByCategoryProvider);
    final categoryProgress = ref.watch(categoryProgressProvider);
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];

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
            child: catalogAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (_) {
                  return CustomScrollView(
                    slivers: [
                      // Open Pack Banner + Trade Banner (mobile only — on wide screens they're in the right panel)
                      if (MediaQuery.sizeOf(context).width < 1000) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                            child: _OpenPackBanner(
                              onTap: () => context.push(AppRoutes.packOpening),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: const TradeButtonCard(),
                          ),
                        ),
                      ],

                      // Top spacing when banner is hidden (wide screens)
                      if (MediaQuery.sizeOf(context).width >= 1000)
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // Categorized Sections
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
        ],
      ),
    );
  }

  void _showCardDetail(BuildContext context, MythCard card, int quantity) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent dismiss on card tap
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Card image (mini mode — name/power/rarity already on it)
                    MythCardWidget(
                      card: card,
                      quantity: quantity,
                    ),
                    const SizedBox(height: 12),
                    // Info panel below
                    _CardDetailInfo(card: card),
                  ],
                ),
              ),
            ),
          ),
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
              card.name,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${card.category.label} collection',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.neutralText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open booster packs to unlock this card!',
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
                  context.push(AppRoutes.packOpening);
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

class _CategorySection extends ConsumerWidget {
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

  Widget _buildCardItem(MythCard card) {
    final isOwned = ownedIds.contains(card.id);
    if (isOwned) {
      final userCard = userCards.where((uc) => uc.cardId == card.id).firstOrNull;
      if (userCard == null) {
        return LockedCardWidget(card: card, onTap: () => onLockedTap(card));
      }
      return MythCardWidget(
        card: card,
        quantity: userCard.quantity,
        onTap: () => onCardTap(card, userCard.quantity),
      );
    }
    return LockedCardWidget(card: card, onTap: () => onLockedTap(card));
  }

  static const _cardWidth = 140.0;
  static const _cardHeight = 220.0;
  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = cards.isEmpty ? 0.0 : ownedCount / cards.length;
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final expandedCategories = ref.watch(expandedCardCategoriesProvider);
    final isExpanded = expandedCategories.contains(category);
    final categoryColor = CardColors.getCategoryColor(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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

        // Cards: horizontal scroll on mobile, 2-row grid + load more on wide
        if (isWide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemsPerRow = ((constraints.maxWidth + _spacing) / (_cardWidth + _spacing)).floor().clamp(1, 20);
                // Show enough rows so all owned cards are visible (min 1 row)
                final lastOwnedIndex = cards.lastIndexWhere((c) => ownedIds.contains(c.id));
                final minRowsForOwned = lastOwnedIndex < 0 ? 1 : ((lastOwnedIndex + 1) / itemsPerRow).ceil();
                final minRows = minRowsForOwned.clamp(1, (cards.length / itemsPerRow).ceil());
                final maxVisible = isExpanded ? cards.length : (minRows * itemsPerRow).clamp(0, cards.length);
                final hasMore = cards.length > maxVisible && !isExpanded;
                final visibleCount = hasMore ? maxVisible - 1 : cards.length;

                return Wrap(
                  spacing: _spacing,
                  runSpacing: _spacing,
                  children: [
                    for (int i = 0; i < visibleCount; i++)
                      SizedBox(
                        width: _cardWidth,
                        height: _cardHeight,
                        child: _buildCardItem(cards[i]),
                      ),
                    if (hasMore)
                      _LoadMoreButton(
                        remaining: cards.length - visibleCount,
                        color: categoryColor,
                        onTap: () {
                          ref.read(expandedCardCategoriesProvider.notifier).state = {
                            ...expandedCategories,
                            category,
                          };
                        },
                      ),
                  ],
                );
              },
            ),
          )
        else
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (context, index) => const SizedBox(width: _spacing),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: _cardWidth,
                  child: _buildCardItem(cards[index]),
                );
              },
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _OpenPackBanner extends ConsumerWidget {
  const _OpenPackBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(unopenedPacksProvider);
    final hasPacks = packs > 0;
    final packCost = ref.watch(systemSettingsProvider).valueOrNull?.packCost ?? 100;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF6B4CFE), Color(0xFFD355FF)],
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
                          hasPacks ? 'PACKS AVAILABLE' : 'GET NEW CARDS',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasPacks
                              ? 'Open Booster Pack ($packs)'
                              : 'Buy Booster Pack',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action badge
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
                    child: hasPacks
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.style_rounded,
                                color: AppColors.cardEpic,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$packs',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.cardEpic,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/icons/gem_outline_256.png', width: 20, height: 20, filterQuality: FilterQuality.high),
                              const SizedBox(width: 6),
                              Text(
                                '$packCost',
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

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.remaining,
    required this.color,
    required this.onTap,
  });

  final int remaining;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        height: 220,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.expand_more_rounded, color: color, size: 32),
              ),
              const SizedBox(height: 10),
              Text(
                '+$remaining more',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Info panel shown below the card in the detail dialog.
class _CardDetailInfo extends ConsumerWidget {
  const _CardDetailInfo({required this.card});
  final MythCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarityColor = Color(card.rarity.colorHex);
    final ownersAsync = ref.watch(cardOwnersInClassProvider(card.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rarity row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  card.rarity.label,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: rarityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CardColors.getRarityStars(card.rarity),
                style: TextStyle(fontSize: 14, color: rarityColor),
              ),
            ],
          ),

          // Description if exists
          if (card.description != null) ...[
            const SizedBox(height: 12),
            Text(
              card.description!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.neutralText,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Special skill if exists
          if (card.specialSkill != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚡ ${card.specialSkill}',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ),
          ],

          // Who owns this card
          const SizedBox(height: 14),
          ownersAsync.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => _buildOwnership(data, rarityColor),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnership(CardOwnersInClass data, Color rarityColor) {
    final ownerCount = data.ownerNames.length;
    final totalStudents = data.totalStudents;

    if (totalStudents == 0) return const SizedBox.shrink();

    if (ownerCount == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_rounded, size: 18, color: rarityColor),
          const SizedBox(width: 4),
          Text(
            'No one else in your class has this!',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: rarityColor,
            ),
          ),
        ],
      );
    }

    final names = ownerCount <= 3
        ? data.ownerNames.join(', ')
        : '${data.ownerNames.take(3).join(', ')} +${ownerCount - 3} more';

    return Column(
      children: [
        Text(
          '$ownerCount of $totalStudents classmates also own this',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.neutralText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          names,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppColors.neutralText,
          ),
        ),
      ],
    );
  }
}
