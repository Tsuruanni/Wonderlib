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
import '../../widgets/cards/coin_badge_widget.dart';
import '../../widgets/cards/pack_glow_widget.dart';
import '../../widgets/common/game_button.dart';

/// Full-screen immersive pack opening experience.
///
/// State flow: idle → purchasing → glowing → revealing → complete
/// This screen is outside the shell (like reader_screen) for full immersion.
class PackOpeningScreen extends ConsumerStatefulWidget {
  const PackOpeningScreen({super.key});

  @override
  ConsumerState<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends ConsumerState<PackOpeningScreen> {
  bool _showLegendaryOverlay = false;
  String? _legendaryCardName;

  @override
  void dispose() {
    // Reset controller when leaving
    ref.read(packOpeningControllerProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(packOpeningControllerProvider);
    final coins = ref.watch(userCoinsProvider);
    final controller = ref.read(packOpeningControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Top bar: back button + coin badge
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
                      CoinBadgeWidget(coins: coins),
                    ],
                  ),
                ),

                // Content area based on phase
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _buildPhaseContent(state, controller, coins),
                    ),
                  ),
                ),
              ],
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
  ) {
    switch (state.phase) {
      case PackOpeningPhase.idle:
        return _buildIdlePhase(controller, coins, state.error);

      case PackOpeningPhase.purchasing:
        return _buildPurchasingPhase();

      case PackOpeningPhase.glowing:
        return _buildGlowingPhase(state, controller);

      case PackOpeningPhase.revealing:
      case PackOpeningPhase.complete:
        return _buildRevealPhase(state, controller, coins);
    }
  }

  Widget _buildIdlePhase(
      PackOpeningController controller, int coins, String? error) {
    final canAfford = coins >= 100;

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

          const SizedBox(height: 40),

          // Cost display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.wasp,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '\u00a2',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '100',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Open button
          SizedBox(
            width: 240,
            height: 56,
            child: GameButton(
              label: 'OPEN PACK',
              variant:
                  canAfford ? GameButtonVariant.wasp : GameButtonVariant.neutral,
              onPressed: canAfford ? () => controller.purchasePack() : null,
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

          if (!canAfford) ...[
            const SizedBox(height: 16),
            Text(
              'Read books and complete activities to earn coins!',
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

  Widget _buildPurchasingPhase() {
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
          'Opening pack...',
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
    int coins,
  ) {
    final packResult = state.packResult!;
    final cards = packResult.cards;
    final isComplete = state.phase == PackOpeningPhase.complete;

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
              final isSpecialSlot = index == 2;

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
                            // Check for legendary reveal
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
                        height: 20, // Reserve height for badge
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
            // Remaining coins
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Remaining: ',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.white.withValues(alpha: 0.6),
                  ),
                ),
                CoinBadgeWidget(coins: packResult.coinsRemaining),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (coins >= 100)
                  Expanded(
                    child: GameButton(
                      label: 'OPEN AGAIN',
                      variant: GameButtonVariant.wasp,
                      onPressed: () {
                        controller.reset();
                        controller.purchasePack();
                      },
                    ),
                  ),
                if (coins >= 100) const SizedBox(width: 16),
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
