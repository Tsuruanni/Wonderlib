import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../../utils/app_icons.dart';
import '../../providers/card_trade_provider.dart';
import '../../widgets/cards/myth_card_widget.dart';
import '../../widgets/common/game_button.dart';

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
      return _TradeRevealView(result: tradeState.result!);
    }

    final dupCounts = ref.watch(tradeableDuplicateCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: AppIcons.arrowBack(),
                  ),
                  Text(
                    'Trade Duplicates',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Segmented tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
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
                labelStyle:
                    GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle:
                    GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
                labelColor: AppColors.black,
                unselectedLabelColor: AppColors.neutralText,
                tabs: [
                  for (final tab in _tabs)
                    Tab(
                      height: 38,
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

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final tab in _tabs) _TradeTab(sourceRarity: tab.source),
              ],
            ),
          ),
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
        Expanded(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Info bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.neutral, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 20,
                          color: isReady
                              ? AppColors.primary
                              : AppColors.neutralText,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Select ${req.count} ${sourceRarity.label.toLowerCase()} cards for 1 ${req.target}',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isReady
                                ? AppColors.primary
                                : AppColors.neutralDark,
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
                ),
              ),

              if (allTargetOwned)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.waspBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          AppIcons.warning(size: 16),
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
                ),

              if (tradeState.error != null)
                SliverToBoxAdapter(
                  child: Padding(
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
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Card grid
              if (cards.isEmpty)
                SliverFillRemaining(
                  child: Center(
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
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: _spacing,
                      runSpacing: _spacing,
                      children: [
                        for (final uc in cards)
                          SizedBox(
                            width: _cardWidth,
                            height: _cardHeight,
                            child: _TradeCardItem(
                              uc: uc,
                              selectedCount:
                                  tradeState.selectedCards[uc.cardId] ?? 0,
                              totalSelected: selected,
                              requiredCount: req.count,
                              isTrading: isTrading,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),

        // Bottom trade button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GameButton(
            label: isReady
                ? (isTrading ? 'Trading...' : 'Trade Now')
                : 'Select ${req.count - selected} more',
            fullWidth: true,
            variant:
                isReady ? GameButtonVariant.primary : GameButtonVariant.neutral,
            onPressed: isReady && !isTrading
                ? () => ref
                    .read(tradeSelectionProvider.notifier)
                    .executeTrade(sourceRarity)
                : null,
          ),
        ),
      ],
    );
  }
}

// ─── Card Item ───

class _TradeCardItem extends ConsumerWidget {
  const _TradeCardItem({
    required this.uc,
    required this.selectedCount,
    required this.totalSelected,
    required this.requiredCount,
    required this.isTrading,
  });

  final UserCard uc;
  final int selectedCount;
  final int totalSelected;
  final int requiredCount;
  final bool isTrading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxTradeable = uc.quantity - 1;
    final isDisabled = maxTradeable <= 0;
    final isSelected = selectedCount > 0;

    return GestureDetector(
      onTap: isDisabled || isTrading
          ? null
          : () {
              if (totalSelected < requiredCount) {
                ref
                    .read(tradeSelectionProvider.notifier)
                    .addCard(uc.cardId, maxAvailable: maxTradeable);
              }
            },
      onLongPress: isDisabled || isTrading || !isSelected
          ? null
          : () =>
              ref.read(tradeSelectionProvider.notifier).removeCard(uc.cardId),
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary, width: 3),
                )
              : null,
          child: Stack(
            children: [
              // Card fills the container (no gap when selected)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(isSelected ? 3 : 4),
                  child: MythCardWidget(card: uc.card),
                ),
              ),

              // Selection count badge
              if (isSelected)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
              if (!isDisabled && !isSelected)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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
                  bottom: 6,
                  right: 6,
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
      ),
    );
  }
}

// ─── Reveal View ───

class _TradeRevealView extends ConsumerWidget {
  const _TradeRevealView({required this.result});
  final TradeResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rarityColor = Color(result.receivedCard.rarity.colorHex);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.isNew ? 'NEW CARD!' : 'CARD RECEIVED',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: result.isNew ? rarityColor : AppColors.black,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                height: 260,
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
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.15),
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
              GameButton(
                label: 'Continue',
                variant: GameButtonVariant.primary,
                onPressed: () {
                  ref
                      .read(tradeSelectionProvider.notifier)
                      .resetAfterReveal();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
