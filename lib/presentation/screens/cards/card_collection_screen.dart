import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
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
                            onTap: () => context.push(AppRoutes.packOpening),
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
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: MythCardWidget(
              card: card,
              isFull: true,
              quantity: quantity,
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

class _OpenPackBanner extends ConsumerWidget {
  const _OpenPackBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(unopenedPacksProvider);
    final hasPacks = packs > 0;

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

