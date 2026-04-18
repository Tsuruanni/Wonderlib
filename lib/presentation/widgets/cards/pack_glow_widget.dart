import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../utils/ui_helpers.dart';

/// Animated pack envelope with pulsing glow based on best card rarity.
///
/// The glow intensity and color indicate the quality of cards inside:
/// - Common (grey): calm, subtle pulse
/// - Rare (blue): moderate pulse
/// - Epic (purple): energetic pulse
/// - Legendary (gold): intense golden glow with particles
class PackGlowWidget extends StatelessWidget {
  const PackGlowWidget({
    super.key,
    required this.glowRarity,
    this.onAnimationComplete,
  });

  final CardRarity glowRarity;
  final VoidCallback? onAnimationComplete;

  @override
  Widget build(BuildContext context) {
    final glowColor = CardColors.getRarityColor(glowRarity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glow container
        Container(
          width: 200,
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2C3E50),
                const Color(0xFF34495E),
                glowColor.withValues(alpha: 0.3),
              ],
            ),
            border: Border.all(color: glowColor.withValues(alpha: 0.6), width: 3),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: glowColor.withValues(alpha: 0.2),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mythic symbol
                Text(
                  '\u2726',
                  style: TextStyle(
                    fontSize: 48,
                    color: glowColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CARD PACK',
                  style: AppTextStyles.titleMedium(color: AppColors.white.withValues(alpha: 0.7)).copyWith(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 3),
                ),
                const SizedBox(height: 4),
                Text(
                  '3 CARDS',
                  style: AppTextStyles.caption(color: AppColors.white.withValues(alpha: 0.4)).copyWith(letterSpacing: 1),
                ),
              ],
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.03, 1.03),
              duration: _glowDuration(glowRarity),
              curve: Curves.easeInOut,
            )
            .then()
            .callback(
              callback: (_) => onAnimationComplete?.call(),
              delay: 1500.ms,
            ),

        const SizedBox(height: 24),

        // "Opening..." text
        Text(
          'Opening...',
          style: AppTextStyles.titleMedium(color: glowColor).copyWith(fontSize: 18),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(
              duration: 800.ms,
            ),
      ],
    );
  }

  Duration _glowDuration(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return 1200.ms;
      case CardRarity.rare:
        return 1000.ms;
      case CardRarity.epic:
        return 800.ms;
      case CardRarity.legendary:
        return 600.ms;
    }
  }
}
