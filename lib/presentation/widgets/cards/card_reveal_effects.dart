import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';

/// "NEW!" badge animation that appears above newly obtained cards.
class NewCardBadge extends StatelessWidget {
  const NewCardBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Text(
        'NEW!',
        style: AppTextStyles.bodyMedium(color: AppColors.white).copyWith(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.0, 0.0),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.elasticOut,
        )
        .then()
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.1),
          duration: 600.ms,
        );
  }
}

/// Duplicate card quantity badge with subtle pulse.
class DuplicateCountBadge extends StatelessWidget {
  const DuplicateCountBadge({super.key, required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '\u00d7$quantity',
        style: AppTextStyles.titleMedium(color: AppColors.white).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.8, 0.8),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }
}

/// Legendary card reveal effect: dark overlay + gold particles + dramatic entrance.
class LegendaryRevealOverlay extends StatelessWidget {
  const LegendaryRevealOverlay({
    super.key,
    required this.cardName,
    required this.onDismiss,
  });

  final String cardName;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gold star burst
              Text(
                '\u2605',
                style: TextStyle(
                  fontSize: 60,
                  color: AppColors.cardLegendary,
                  shadows: [
                    Shadow(
                      color: AppColors.cardLegendary.withValues(alpha: 0.6),
                      blurRadius: 30,
                    ),
                  ],
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.0, 0.0),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  )
                  .then()
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(
                    begin: -0.05,
                    end: 0.05,
                    duration: 1000.ms,
                  ),

              const SizedBox(height: 16),

              // LEGENDARY label
              Text(
                'LEGENDARY',
                style: AppTextStyles.headlineLarge(color: AppColors.cardLegendary).copyWith(letterSpacing: 4, shadows: [
                    Shadow(
                      color: AppColors.cardLegendary.withValues(alpha: 0.5),
                      blurRadius: 20,
                    ),
                  ]),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms),

              const SizedBox(height: 8),

              // Card name
              Text(
                cardName,
                style: AppTextStyles.titleLarge(color: AppColors.white).copyWith(fontWeight: FontWeight.w700),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

              const SizedBox(height: 24),

              // Tap to continue
              Text(
                'Tap to continue',
                style: AppTextStyles.bodyMedium(color: AppColors.white.withValues(alpha: 0.5)).copyWith(fontSize: 14),
              )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 400.ms)
                  .then()
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(
                    duration: 800.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
