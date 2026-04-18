import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../../utils/app_icons.dart';
import '../../providers/system_settings_provider.dart';
import '../../widgets/cards/card_reveal_effects.dart';
import '../../widgets/cards/coin_badge.dart';
import '../../widgets/cards/rive_pack_reveal_widget.dart';
import '../../widgets/common/app_chip.dart';
import '../../widgets/common/game_button.dart';

/// Full-screen immersive pack opening experience.
///
/// State flow:
///   Open: idle → opening → glowing → revealing → complete
///   Buy:  idle → buying → idle (with buySuccess feedback)
class PackOpeningScreen extends ConsumerStatefulWidget {
  const PackOpeningScreen({super.key});

  @override
  ConsumerState<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends ConsumerState<PackOpeningScreen> {
  bool _showLegendaryOverlay = false;
  String? _legendaryCardName;
  bool _showBuyFeedback = false;
  Future<PreloadedRiveData>? _preloadFuture;

  @override
  void dispose() {
    // reset() is called by the "DONE" button before pop.
    // Calling ref.read() here is unsafe — WidgetRef may already be invalidated.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(packOpeningControllerProvider);
    final coins = ref.watch(userCoinsProvider);
    final packs = ref.watch(unopenedPacksProvider);
    final controller = ref.read(packOpeningControllerProvider.notifier);

    // Show buy success feedback
    if (state.buySuccess && !_showBuyFeedback) {
      _showBuyFeedback = true;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showBuyFeedback = false);
      });
    }
    if (!state.buySuccess) {
      _showBuyFeedback = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Top bar: back button + pack count + coin badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: AppIcons.arrowBack(),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      // Pack count badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: packs > 0
                              ? AppColors.cardEpic.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: packs > 0
                                ? AppColors.cardEpic.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.style_rounded,
                              size: 16,
                              color: packs > 0 ? AppColors.cardEpic : AppColors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$packs',
                              style: AppTextStyles.bodyMedium(color: packs > 0 ? AppColors.cardEpic : AppColors.white.withValues(alpha: 0.5)).copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      CoinBadge(coins: coins),
                    ],
                  ),
                ),

                // Content area based on phase
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: _buildPhaseContent(state, controller, coins, packs),
                  ),
                ),
              ],
            ),

            // Buy success feedback overlay
            if (_showBuyFeedback)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.white, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pack added to inventory!',
                            style: AppTextStyles.titleMedium(color: AppColors.white).copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.3),
                ),
              ),

            // Legendary overlay
            if (_showLegendaryOverlay && _legendaryCardName != null)
              LegendaryRevealOverlay(
                cardName: _legendaryCardName!,
                onDismiss: () =>
                    setState(() => _showLegendaryOverlay = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseContent(
    PackOpeningState state,
    PackOpeningController controller,
    int coins,
    int packs,
  ) {
    // Session-scoped key prefix prevents AnimatedSwitcher duplicate-key
    // crashes when rapidly cycling through phases (old widgets still
    // fading out can collide with new widgets of the same phase).
    final s = state.sessionId;
    // Reset preload future when returning to idle
    if (state.phase == PackOpeningPhase.idle) {
      _preloadFuture = null;
    }

    // Start preloading as soon as RPC returns packResult during opening
    if (state.phase == PackOpeningPhase.opening &&
        state.packResult != null &&
        _preloadFuture == null) {
      final minWait = Future<void>.delayed(const Duration(seconds: 2));
      _preloadFuture =
          preloadRiveCards(state.packResult!.cards).then((data) async {
        await minWait;
        if (mounted) controller.forceReveal();
        return data;
      });
    }

    switch (state.phase) {
      case PackOpeningPhase.idle:
        return KeyedSubtree(
          key: ValueKey('idle_$s'),
          child: _buildIdlePhase(controller, coins, packs, state.error),
        );

      case PackOpeningPhase.buying:
        return KeyedSubtree(
          key: ValueKey('buying_$s'),
          child: _buildPurchasingPhase(),
        );

      case PackOpeningPhase.opening:
      case PackOpeningPhase.glowing:
        return KeyedSubtree(
          key: ValueKey('opening_$s'),
          child: _buildPurchasingPhase(),
        );

      case PackOpeningPhase.revealing:
      case PackOpeningPhase.complete:
        return KeyedSubtree(
          key: ValueKey('reveal_$s'),
          child: _buildRevealPhase(state, controller, packs),
        );
    }
  }

  Widget _buildIdlePhase(
      PackOpeningController controller, int coins, int packs, String? error,) {
    final packCost =
        ref.watch(systemSettingsProvider).valueOrNull?.packCost ?? 100;
    final canAfford = coins >= packCost;
    final hasPacks = packs > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        final cardFan = SizedBox(
          width: isWide ? 320 : 260,
          height: isWide ? 340 : 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: isWide ? 20 : 10,
                child: Transform.rotate(
                  angle: -0.18,
                  child: _buildCardBack(scale: isWide ? 0.95 : 0.85),
                ),
              ),
              Positioned(
                right: isWide ? 20 : 10,
                child: Transform.rotate(
                  angle: 0.18,
                  child: _buildCardBack(scale: isWide ? 0.95 : 0.85),
                ),
              ),
              _buildCardBack(scale: isWide ? 1.05 : 0.95),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.97, 0.97),
              end: const Offset(1.03, 1.03),
              duration: 2500.ms,
              curve: Curves.easeInOut,
            )
            .shimmer(
              duration: 3000.ms,
              color: AppColors.cardEpic.withValues(alpha: 0.1),
            );

        final infoPanel = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'MYTHIC PACK',
              style: AppTextStyles.titleMedium(color: AppColors.white).copyWith(fontSize: isWide ? 28 : 24, fontWeight: FontWeight.w900, letterSpacing: 6),
            ),
            const SizedBox(height: 6),
            Text(
              '3 Mythology Cards Inside',
              style: AppTextStyles.bodySmall(color: AppColors.white.withValues(alpha: 0.4)).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),

            // Buttons
            if (hasPacks) ...[
              SizedBox(
                width: 260,
                height: 52,
                child: GameButton(
                  label: 'OPEN PACK  ($packs)',
                  variant: GameButtonVariant.wasp,
                  onPressed: () => controller.openPack(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: 260,
              height: hasPacks ? 42 : 52,
              child: GameButton(
                label: 'BUY PACK  $packCost',
                icon: Image.asset(
                  'assets/icons/gem_outline_256.png',
                  width: 18,
                  height: 18,
                  filterQuality: FilterQuality.high,
                ),
                variant: canAfford
                    ? (hasPacks
                        ? GameButtonVariant.neutral
                        : GameButtonVariant.primary)
                    : GameButtonVariant.neutral,
                onPressed: canAfford
                    ? () => controller.buyPack(cost: packCost)
                    : null,
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: AppTextStyles.bodySmall(color: AppColors.danger).copyWith(fontWeight: FontWeight.w600),
              ),
            ],

            if (!hasPacks && !canAfford) ...[
              const SizedBox(height: 12),
              Text(
                'Complete quests or read books\nto earn packs!',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(color: AppColors.white.withValues(alpha: 0.4)),
              ),
            ],
          ],
        );

        if (isWide) {
          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                cardFan,
                const SizedBox(width: 40),
                infoPanel,
              ],
            ),
          );
        }

        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                cardFan,
                const SizedBox(height: 24),
                infoPanel,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardBack({double scale = 1.0}) {
    return Container(
      width: 140 * scale,
      height: 200 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1A3E), Color(0xFF1A1A2E), Color(0xFF2A1A3E)],
        ),
        border: Border.all(
          color: AppColors.cardEpic.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.cardEpic.withValues(alpha: 0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Corner decorations
          Positioned(
            top: 12 * scale,
            left: 12 * scale,
            child: _buildCornerDot(scale),
          ),
          Positioned(
            top: 12 * scale,
            right: 12 * scale,
            child: _buildCornerDot(scale),
          ),
          Positioned(
            bottom: 12 * scale,
            left: 12 * scale,
            child: _buildCornerDot(scale),
          ),
          Positioned(
            bottom: 12 * scale,
            right: 12 * scale,
            child: _buildCornerDot(scale),
          ),
          // Center emblem
          Container(
            width: 50 * scale,
            height: 50 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.cardEpic.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                '\u2726',
                style: TextStyle(
                  fontSize: 24 * scale,
                  color: AppColors.cardEpic.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerDot(double scale) {
    return Container(
      width: 6 * scale,
      height: 6 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardEpic.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildPurchasingPhase() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated card back with pulse
          SizedBox(
            width: 160,
            height: 220,
            child: _buildCardBack(scale: 1.1),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: 800.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(
                duration: 1200.ms,
                color: AppColors.cardEpic.withValues(alpha: 0.3),
              ),
        ],
      ),
    );
  }

  Widget _buildRevealPhase(
    PackOpeningState state,
    PackOpeningController controller,
    int packs,
  ) {
    final packResult = state.packResult!;
    final cards = packResult.cards;
    final isComplete = state.phase == PackOpeningPhase.complete;
    final packsRemaining = packResult.packsRemaining;

    return Column(
      children: [
        // Rive card reveal animation
        if (!isComplete)
          Expanded(
              child: FutureBuilder<PreloadedRiveData>(
                future: _preloadFuture ??= preloadRiveCards(cards),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.cardEpic,
                      ),
                    );
                  }
                  return RivePackRevealWidget(
                    cards: cards,
                    preloadedData: snapshot.data!,
                    onCardRevealed: (index) {
                      // Legendary overlay on first sight
                      final revealedCard = cards[index].card;
                      if (revealedCard.rarity == CardRarity.legendary &&
                          !_showLegendaryOverlay) {
                        Future.delayed(const Duration(milliseconds: 700), () {
                          if (mounted) {
                            setState(() {
                              _showLegendaryOverlay = true;
                              _legendaryCardName = revealedCard.name;
                            });
                          }
                        });
                      }
                    },
                    onAllRevealed: () {
                      // Delay reset to next frame so AnimatedSwitcher
                      // can cleanly dispose the revealing widget.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) controller.reset();
                      });
                    },
                  );
                },
              ),
            ),

          // Complete phase: summary + action buttons
          if (isComplete) ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Packs remaining: ',
                        style: AppTextStyles.titleMedium(color: AppColors.white.withValues(alpha: 0.6)).copyWith(fontSize: 16),
                      ),
                      AppChip(
                        label: '$packsRemaining',
                        variant: AppChipVariant.custom,
                        uppercase: false,
                        customColor: AppColors.cardEpic,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (packsRemaining > 0)
                        Expanded(
                          child: GameButton(
                            label: 'OPEN AGAIN',
                            variant: GameButtonVariant.wasp,
                            onPressed: () {
                              controller.reset();
                              controller.openPack();
                            },
                          ),
                        ),
                      if (packsRemaining > 0) const SizedBox(width: 16),
                      Expanded(
                        child: GameButton(
                          label: 'DONE',
                          variant: GameButtonVariant.neutral,
                          onPressed: () {
                            controller.reset();
                            context.pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ],
      );
  }
}
