import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../../providers/card_trade_provider.dart';
import '../../widgets/cards/myth_card_widget.dart';

class CardTradeScreen extends ConsumerStatefulWidget {
  const CardTradeScreen({super.key});

  @override
  ConsumerState<CardTradeScreen> createState() => _CardTradeScreenState();
}

class _CardTradeScreenState extends ConsumerState<CardTradeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (source: CardRarity.common, label: 'Common → Rare'),
    (source: CardRarity.rare, label: 'Rare → Epic'),
    (source: CardRarity.epic, label: 'Epic → Legendary'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(tradeSelectionProvider.notifier).clearSelection();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tradeState = ref.watch(tradeSelectionProvider);
    final dupCounts = ref.watch(tradeableDuplicateCountProvider);

    // Show reveal overlay
    if (tradeState.phase == TradePhase.reveal && tradeState.result != null) {
      return _TradeRevealOverlay(result: tradeState.result!);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Trade Duplicates',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            for (final tab in _tabs)
              Tab(
                child: Opacity(
                  opacity: (dupCounts[tab.source] ?? 0) >=
                          (tradeRequirements[tab.source]?.count ?? 99)
                      ? 1.0
                      : 0.4,
                  child: Text(tab.label),
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in _tabs)
            _TradeTab(sourceRarity: tab.source),
        ],
      ),
    );
  }
}

class _TradeTab extends ConsumerWidget {
  const _TradeTab({required this.sourceRarity});
  final CardRarity sourceRarity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(tradeGridCardsProvider(sourceRarity));
    final tradeState = ref.watch(tradeSelectionProvider);
    final req = tradeRequirements[sourceRarity]!;
    final selected = tradeState.totalSelected;
    final isReady = selected == req.count;
    final isTrading = tradeState.phase == TradePhase.trading;

    // Check if user owns all cards of the target rarity
    final userCards = ref.watch(userCardsProvider).valueOrNull ?? [];
    final catalog = ref.watch(cardCatalogProvider).valueOrNull ?? [];
    final targetRarityTotal = catalog.where((c) => c.rarity.dbValue == req.target).length;
    final targetRarityOwned = userCards.where((uc) => uc.card.rarity.dbValue == req.target).length;
    final allTargetOwned = targetRarityTotal > 0 && targetRarityOwned >= targetRarityTotal;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Select ${req.count} ${sourceRarity.label.toLowerCase()} cards to trade for 1 ${req.target} card',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$selected / ${req.count}',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isReady ? AppColors.primary : AppColors.neutralText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'selected',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Warning: all target rarity cards owned
        if (allTargetOwned)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.waspBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.wasp, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You own all ${req.target} cards — you\'ll get a duplicate',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.waspDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Error message
        if (tradeState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              tradeState.error!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),

        // Card grid
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Text(
                    'No ${sourceRarity.label.toLowerCase()} cards yet',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.neutralText,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final uc = cards[index];
                    final maxTradeable = uc.quantity - 1;
                    final selectedCount =
                        tradeState.selectedCards[uc.cardId] ?? 0;
                    final isDisabled = maxTradeable <= 0;

                    return GestureDetector(
                      onTap: isDisabled || isTrading
                          ? null
                          : () {
                              final notifier =
                                  ref.read(tradeSelectionProvider.notifier);
                              if (selectedCount > 0 &&
                                  selectedCount >= maxTradeable) {
                                notifier.removeCard(uc.cardId);
                              } else if (selected < req.count) {
                                notifier.addCard(uc.cardId,
                                    maxAvailable: maxTradeable,);
                              }
                            },
                      onLongPress: isDisabled || isTrading || selectedCount == 0
                          ? null
                          : () => ref
                              .read(tradeSelectionProvider.notifier)
                              .removeCard(uc.cardId),
                      child: Opacity(
                        opacity: isDisabled ? 0.4 : 1.0,
                        child: Stack(
                          children: [
                            MythCardWidget(card: uc.card),
                            // Selection overlay
                            if (selectedCount > 0)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            // Selection count badge
                            if (selectedCount > 0)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '-$selectedCount',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            // Available badge (bottom-left for non-disabled)
                            if (!isDisabled && selectedCount == 0)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'x${uc.quantity}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            // Lock icon for disabled
                            if (isDisabled)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Trade button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isReady && !isTrading
                  ? () => ref
                      .read(tradeSelectionProvider.notifier)
                      .executeTrade(sourceRarity)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.neutral,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isTrading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Trade ${req.count} Cards',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TradeRevealOverlay extends ConsumerWidget {
  const _TradeRevealOverlay({required this.result});
  final TradeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarityColor = Color(result.receivedCard.rarity.colorHex);

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.isNew)
                Text(
                  'NEW CARD!',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: rarityColor,
                  ),
                )
              else
                Text(
                  'CARD RECEIVED',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: MythCardWidget(
                  card: result.receivedCard,
                  showNewBadge: result.isNew,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                result.receivedCard.name,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  result.receivedCard.rarity.label,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: rarityColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(tradeSelectionProvider.notifier).resetAfterReveal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
