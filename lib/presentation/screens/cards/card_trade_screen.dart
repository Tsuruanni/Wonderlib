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

    if (tradeState.phase == TradePhase.reveal && tradeState.result != null) {
      return _TradeRevealOverlay(result: tradeState.result!);
    }

    final dupCounts = ref.watch(tradeableDuplicateCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Trade Duplicates',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelPadding: EdgeInsets.zero,
              padding: const EdgeInsets.all(4),
              labelStyle: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              labelColor: AppColors.black,
              unselectedLabelColor: AppColors.neutralText,
              tabs: [
                for (final tab in _tabs)
                  Tab(
                    height: 36,
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
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final tab in _tabs) _TradeTab(sourceRarity: tab.source),
        ],
      ),
    );
  }
}

// ─── Trade Tab ───

class _TradeTab extends ConsumerWidget {
  const _TradeTab({required this.sourceRarity});
  final CardRarity sourceRarity;

  static const _cardWidth = 140.0;
  static const _cardHeight = 220.0;
  static const _spacing = 12.0;

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
    final targetRarityTotal =
        catalog.where((c) => c.rarity.dbValue == req.target).length;
    final targetRarityOwned =
        userCards.where((uc) => uc.card.rarity.dbValue == req.target).length;
    final allTargetOwned =
        targetRarityTotal > 0 && targetRarityOwned >= targetRarityTotal;

    return Column(
      children: [
        const SizedBox(height: 16),

        // Progress pill
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isReady
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.gray100,
            borderRadius: BorderRadius.circular(14),
            border: isReady
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: isReady ? AppColors.primary : AppColors.neutralText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trade ${req.count} ${sourceRarity.label.toLowerCase()} → 1 ${req.target}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isReady ? AppColors.primary : AppColors.neutralDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$selected / ${req.count}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Warnings
        if (allTargetOwned)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.waspBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.wasp, size: 16),
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

        if (tradeState.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tradeState.error!,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Card grid — same sizing as collection page
        Expanded(
          child: cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.style_outlined,
                          size: 48, color: AppColors.neutral),
                      const SizedBox(height: 12),
                      Text(
                        'No ${sourceRarity.label.toLowerCase()} cards yet',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutralText,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: _spacing,
                    runSpacing: _spacing,
                    children: [
                      for (final uc in cards)
                        SizedBox(
                          width: _cardWidth,
                          height: _cardHeight,
                          child: _buildCardItem(
                            uc: uc,
                            tradeState: tradeState,
                            selected: selected,
                            req: req,
                            isTrading: isTrading,
                            ref: ref,
                          ),
                        ),
                    ],
                  ),
                ),
        ),

        // Trade button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
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
                  elevation: 0,
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
                        isReady ? 'Trade Now' : 'Select ${req.count - selected} more',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardItem({
    required UserCard uc,
    required TradeSelectionState tradeState,
    required int selected,
    required ({int count, String target}) req,
    required bool isTrading,
    required WidgetRef ref,
  }) {
    final maxTradeable = uc.quantity - 1;
    final selectedCount = tradeState.selectedCards[uc.cardId] ?? 0;
    final isDisabled = maxTradeable <= 0;

    return GestureDetector(
      onTap: isDisabled || isTrading
          ? null
          : () {
              final notifier = ref.read(tradeSelectionProvider.notifier);
              if (selectedCount > 0 && selectedCount >= maxTradeable) {
                notifier.removeCard(uc.cardId);
              } else if (selected < req.count) {
                notifier.addCard(uc.cardId, maxAvailable: maxTradeable);
              }
            },
      onLongPress: isDisabled || isTrading || selectedCount == 0
          ? null
          : () =>
              ref.read(tradeSelectionProvider.notifier).removeCard(uc.cardId),
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Stack(
          children: [
            MythCardWidget(card: uc.card),

            // Selection border
            if (selectedCount > 0)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                ),
              ),

            // Selection count badge
            if (selectedCount > 0)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

            // Quantity badge
            if (!isDisabled && selectedCount == 0)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

            // Lock for quantity=1
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
  }
}

// ─── Reveal Overlay ───

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
              Text(
                result.isNew ? 'NEW CARD!' : 'CARD RECEIVED',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: result.isNew ? rarityColor : Colors.white,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: rarityColor.withValues(alpha: 0.4)),
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
                  ref
                      .read(tradeSelectionProvider.notifier)
                      .resetAfterReveal();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
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
