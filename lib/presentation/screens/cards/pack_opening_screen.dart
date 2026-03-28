import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../providers/card_provider.dart';
import '../../widgets/cards/card_flip_widget.dart';
import '../../widgets/cards/card_reveal_effects.dart';
import '../../widgets/cards/coin_badge.dart';
import '../../widgets/cards/pack_glow_widget.dart';
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
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.white),
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
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: packs > 0 ? AppColors.cardEpic : AppColors.white.withValues(alpha: 0.5),
                              ),
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
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _buildPhaseContent(state, controller, coins, packs),
                    ),
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
                        Text(
                          'Pack added to inventory!',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
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
    switch (state.phase) {
      case PackOpeningPhase.idle:
        return _buildIdlePhase(controller, coins, packs, state.error);

      case PackOpeningPhase.buying:
        return _buildPurchasingPhase('Buying pack...');

      case PackOpeningPhase.opening:
        return _buildPurchasingPhase('Opening pack...');

      case PackOpeningPhase.glowing:
        return _buildGlowingPhase(state, controller);

      case PackOpeningPhase.revealing:
      case PackOpeningPhase.complete:
        return _buildRevealPhase(state, controller, packs);
    }
  }

  Widget _buildIdlePhase(
      PackOpeningController controller, int coins, int packs, String? error) {
    final canAfford = coins >= 100;
    final hasPacks = packs > 0;

    return Padding(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium 3D Pack Visual
          Container(
            width: 220,
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C3E50), Color(0xFF1A1A2E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardEpic.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Metallic sheen
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
                // Pack Content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cardEpic.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cardEpic.withValues(alpha: 0.2),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Text(
                          '\u2726',
                          style: TextStyle(
                            fontSize: 48,
                            color: AppColors.cardEpic,
                            shadows: [
                              Shadow(
                                color: AppColors.cardEpic,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'MYTHIC PACK',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cardEpic.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.cardEpic.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '3 CARDS',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.cardEpic,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(0.98, 0.98),
                end: const Offset(1.02, 1.02),
                duration: 2000.ms,
                curve: Curves.easeInOut,
              ),

          const SizedBox(height: 32),

          // Pack count indicator
          if (hasPacks)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.cardEpic.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.cardEpic.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'You have $packs pack${packs > 1 ? 's' : ''}',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cardEpic,
                ),
              ),
            ),

          // OPEN PACK button (primary action — from inventory)
          SizedBox(
            width: 240,
            height: 56,
            child: GameButton(
              label: 'OPEN PACK',
              variant:
                  hasPacks ? GameButtonVariant.wasp : GameButtonVariant.neutral,
              onPressed: hasPacks ? () => controller.openPack() : null,
            ),
          ),

          const SizedBox(height: 12),

          // BUY PACK button (secondary action — with coins)
          SizedBox(
            width: 240,
            height: 48,
            child: GameButton(
              label: 'BUY PACK  \u00a2100',
              variant: canAfford ? GameButtonVariant.primary : GameButtonVariant.neutral,
              onPressed: canAfford ? () => controller.buyPack() : null,
            ),
          ),

          // Error message
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],

          if (!hasPacks && !canAfford) ...[
            const SizedBox(height: 16),
            Text(
              'Complete daily quests or read books to get packs!',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPurchasingPhase(String message) {
    return Column(
      key: const ValueKey('purchasing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            color: AppColors.cardEpic,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGlowingPhase(
      PackOpeningState state, PackOpeningController controller) {
    return PackGlowWidget(
      key: const ValueKey('glowing'),
      glowRarity: state.packResult!.packGlowRarity,
      onAnimationComplete: () => controller.startRevealing(),
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

    return Padding(
      key: const ValueKey('reveal'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 3 cards side by side
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(cards.length, (index) {
              final packCard = cards[index];
              final isRevealed = state.revealedIndices.contains(index);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 180,
                        child: CardFlipWidget(
                          card: packCard.card,
                          isRevealed: isRevealed,
                          quantity: packCard.currentQuantity,
                          isNew: packCard.isNew,
                          index: index,
                          onFlip: () {
                            controller.revealCard(index);
                            if (packCard.card.rarity == CardRarity.legendary) {
                              Future.delayed(const Duration(milliseconds: 700),
                                  () {
                                if (mounted) {
                                  setState(() {
                                    _showLegendaryOverlay = true;
                                    _legendaryCardName = packCard.card.name;
                                  });
                                }
                              });
                            }
                          },
                        ),
                      ),

                      // NEW/duplicate indicator after reveal
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 20,
                        child: isRevealed
                            ? Center(
                                child: packCard.isNew
                                    ? const NewCardBadge()
                                    : DuplicateCountBadge(
                                        quantity: packCard.currentQuantity),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 40),

          // Complete phase: summary + action buttons
          if (isComplete) ...[
            // Remaining packs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Packs remaining: ',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.white.withValues(alpha: 0.6),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardEpic.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$packsRemaining',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cardEpic,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
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
          ] else ...[
            // Hint to tap cards
            Text(
              'Tap cards to reveal',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.white.withValues(alpha: 0.5),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn(duration: 800.ms),
          ],
        ],
      ),
    );
  }
}
